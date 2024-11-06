local flib_format = require("__flib__.format")

--- @class sigd_display
local sigd_display = {}

-- Ensure this entity is a valid display panel
local function validate(entity)
    return entity and entity.type == "display-panel" and entity.valid
end

-- Register a dispaly for updates with the mod
local function add_display(display)
    if not validate(display) then return end
    local surface_index = display.surface.index
    if not storage.displays then
        storage.displays = {}
    end

    if not storage.displays[surface_index] then
        storage.displays[surface_index] = {}
    end

    storage.displays[surface_index][display.unit_number] = display
    storage.display_signals[display.unit_number] = {}
end

-- Remove a display from the mod updates
local function remove_display(display)
    if not display.unit_number or not display.surface then return end
    if not storage.displays then return end

    local surface_index = display.surface.index
    if not storage.displays[surface_index] then return end
    storage.displays[surface_index][display.unit_number] = nil

    if not storage.display_signals then return end
    storage.display_signals[display.unit_number] = nil

    -- if this was the last display on the surface, restart from begining
    if storage.display_index[surface_index] == display.unit_number then
        storage.display_index[surface_index] = nil
    end
end

-- get last signal from a dispaly that was cached or -1 if not found
local function get_last_signal(display, signal)
    if not storage.display_signals or not storage.display_signals[display.unit_number] then
        return -1
    end
    return storage.display_signals[display.unit_number][signal] or -1
end

-- Function to extract all attributes from a rich text string
local function parseRichText(text)
    local parts = {}
    local currentSearchText = text

    -- Trim the string until done
    while currentSearchText ~= nil and #currentSearchText > 0 do
        -- Get the next x=y parameter
        local paramStart, paramEnd = string.find(currentSearchText, "[%w%-]+=[%w%-]+")

        -- Nothing found so string is done
        if (paramStart == nil or paramEnd == nil) then
            currentSearchText = nil
            break
        end

        -- Extract key and value and store it
        local currentParam = string.sub(currentSearchText, paramStart, paramEnd)
        for key, value in string.gmatch(currentParam, "([%w%-]+)=([%w%-]+)") do
            parts[key] = value
        end

        -- Trim text by the part we just extracted
        currentSearchText = string.sub(currentSearchText, paramEnd + 1, #currentSearchText)
    end

    return parts
end


-- Function to find all the rich texts inside a display string
local function parseDisplayText(text)
    local richTexts = {}
    local currentSearchText = text

    -- Search the text until done
    while (currentSearchText ~= nil and #currentSearchText > 0) do
        -- Strip the next rich text tag out e.g [item=rocket-turret,quality=rare]
        local signalStart, signalEnd = string.find(currentSearchText, "%[[%w%-=,]+%]")

        -- No rich text found, nothing left to do
        if (signalStart == nil or signalEnd == nil) then
            currentSearchText = nil
            break
        end

        -- Extract the rich text and parse it
        local currentSignal = string.sub(currentSearchText, signalStart, signalEnd)
        table.insert(richTexts, parseRichText(currentSignal))

        -- Trim text by the part we just extraced
        currentSearchText = string.sub(currentSearchText, signalEnd + 1, #currentSearchText)
    end

    return richTexts
end

-- Function to be lazy and extend if any other signals need converting from one value to another
local function convert(text)
    local conversionTable = {
        ["virtual-signal"] = "virtual",
        ["planet"] = "space-location"
    }

    if conversionTable[text] ~= nil then
        return conversionTable[text]
    end

    return text
end

-- Function to find the prototype type of a given parsed rich text
local function getType(params)
    local types = {
        "item",
        "fluid",
        "virtual-signal",
        "entity",
        "recipe",
        "space-location",
        "asteroid-chunk",
        "planet"
    }

    for _, value in pairs(types) do
        if params[value] ~= null then
            return value
        end
    end

    return nil
end

-- update the display with the current signals
function sigd_display.update_display(display)
    local control = display.get_or_create_control_behavior()
    if not control then return end

    for i, message in pairs(control.messages) do
        local text = message.text
        if not text or (message.condition and message.condition.fulfilled == false) then goto next_message end
        local n = 0
        local updated = false

        -- Update based on icons
        local icon = message.icon
        local icon_name = icon and icon.name or "unset"
        local signal = icon_name ~= "unset" and display.get_signal(icon, defines.wire_connector_id.circuit_green,
            defines.wire_connector_id.circuit_red) or 0

        if signal ~= get_last_signal(display, icon_name) then
            storage.display_signals[display.unit_number][icon_name] = signal
            if storage.show_formatted_number then
                signal = flib_format.number(signal, true)
            end
            text, n = text:gsub("%[[%dQRYZEPTGMk %.]*%]", "[" .. signal .. "]", 1)
            if n > 0 then
                updated = true
            end
        end

        -- Update based on rich text
        if storage.search_rich_text then
            for typ, value in text:gmatch("%[([%w%-]+)=([%w%-]+)]") do
                -- Update typ to match SignalIDType
                if typ == "item" then typ = nil end
                if typ == "virtual-signal" then typ = "virtual" end
                signal = display.get_signal({ name = value, type = typ }, defines.wire_connector_id.circuit_green,
                    defines.wire_connector_id.circuit_red)

                if value ~= icon_name and signal == get_last_signal(display, value) then
                    goto next_match
                end
                storage.display_signals[display.unit_number][value] = signal
                if storage.show_formatted_number then
                    signal = flib_format.number(signal, true)
                end

                text, n = text:gsub("(=" .. value:gsub("%-", "%%-") .. "%])(%[[%dQRYZEPTGMk %.]*%])",
                    "%1[" .. signal .. "]", 1)
                if n > 0 then
                    updated = true
                end
                :: next_match ::
            end
        end
        if updated then
            control.set_message(i, { text = text, icon = icon, condition = message.condition })
        end
        :: next_message ::
    end
end

-- register a new display when built
--- @param e EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_space_platform_built_entity |EventData.on_entity_cloned|EventData.script_raised_revive
function sigd_display.on_display_created(e)
    local display = e.destination or e.entity
    add_display(display)
end

-- remove a display when mined or destroyed
--- @param e EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined|EventData.on_space_platform_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
function sigd_display.on_display_deleted(e)
    local display = e.entity
    remove_display(display)
end

sigd_display.add_display = add_display

return sigd_display
