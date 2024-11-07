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
---@param display LuaEntity display panel
---@param signal string signal name
---@param quality string? quality of this item
---@return integer -1 if not found, else the last signal value
local function get_last_signal(display, signal, quality)
    if not storage.display_signals or not storage.display_signals[display.unit_number] then
        return -1
    end
    local key = signal .. (quality and "-" .. quality or "")
    return storage.display_signals[display.unit_number][key] or -1
end

-- set the last signal for a display
---@param display LuaEntity display panel
---@param signal string signal name
---@param value integer value of the signal
---@param quality string? quality of this item
local function set_last_signal(display, signal, value, quality)
    if not storage.display_signals or not storage.display_signals[display.unit_number] then
        return
    end
    local key = signal .. (quality and "-" .. quality or "")
    storage.display_signals[display.unit_number][key] = value
end

-- convert rich richText Syntax to SignalIDType
local function text_to_signalID(type)
    local idMap = {
        ["item"] = "item",
        ["fluid"] = "fluid",
        ["virtual-signal"] = "virtual",
        ["entity"] = "entity",
        ["recipe"] = "recipe",
        ["planet"] = "space-location",
        ["space-location"] = "space-location",
        -- Currently asteriods can not be used in rich text
        -- ["asteroid-chunk"] = "asteroid-chunk",
        ["quality"] = "quality"
    }

    return idMap[type]
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
        local icon_quality = icon and icon.quality or nil -- can be nil
        local signal = icon_name ~= "unset" and display.get_signal(icon, defines.wire_connector_id.circuit_green,
            defines.wire_connector_id.circuit_red) or 0

        if signal ~= get_last_signal(display, icon_name, icon_quality) then
            set_last_signal(display, icon_name, signal, icon_quality)
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
            for typ, value in text:gmatch("%[([%w%-]+)=([%w%-]+)%]") do
                -- Update typ to match SignalIDType
                typ = text_to_signalID(typ)
                if not typ then goto next_match end
                signal = display.get_signal({ name = value, type = typ },
                    defines.wire_connector_id.circuit_green,
                    defines.wire_connector_id.circuit_red)

                if value ~= icon_name and signal == get_last_signal(display, value) then
                    goto next_match
                end
                set_last_signal(display, value, signal)
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
            -- we have to do quality separately as there is not way to do optional groups in Lua patterns
            for typ, value, quality in text:gmatch("%[([%w%-]+)=([%w%-]+),quality=([%w%-]+)%]") do
                -- Update typ to match SignalIDType
                typ = text_to_signalID(typ)
                if not typ then goto next_match end
                signal = display.get_signal({ name = value, type = typ, quality = quality },
                    defines.wire_connector_id.circuit_green,
                    defines.wire_connector_id.circuit_red)

                if value ~= icon_name and quality ~= icon_quality and signal == get_last_signal(display, value, quality) then
                    goto next_match
                end
                set_last_signal(display, value, signal, quality)
                if storage.show_formatted_number then
                    signal = flib_format.number(signal, true)
                end
                text, n = text:gsub(
                    "(=" ..
                    value:gsub("%-", "%%-") .. ",quality=" .. quality:gsub("%-", "%%-") .. "%])(%[[%dQRYZEPTGMk %.]*%])",
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
--- @param e EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_space_platform_built_entity|EventData.on_entity_cloned|EventData.script_raised_revive|EventData.script_raised_built
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
