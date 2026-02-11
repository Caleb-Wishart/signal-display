local flib_format = require("__flib__.format")

--- @class sigd_display
local sigd_display = {}

-- Ensure this entity is a valid display panel
local function validate(entity)
    return entity and (entity.type == "display-panel" or entity.type == "programmable-speaker") and entity.valid
end

-- Register a display for updates with the mod
local function add_display(display)
    if not validate(display) then
        return
    end
    local surface_index = display.surface.index
    if not storage.displays then
        storage.displays = {}
    end

    if not storage.displays[surface_index] then
        storage.displays[surface_index] = {}
    end

    storage.displays[surface_index][display.unit_number] = display
    -- Create signal cache
    storage.display_signals[display.unit_number] = {}
end

-- Remove a display from the mod updates
local function remove_display(display)
    if not display.unit_number or not display.surface then
        return
    end
    if not storage.displays then
        return
    end

    local surface_index = display.surface.index
    if not storage.displays[surface_index] then
        return
    end
    storage.displays[surface_index][display.unit_number] = nil

    if not storage.display_signals then
        return
    end
    storage.display_signals[display.unit_number] = nil

    -- if this was the last display on the surface, restart from beginning
    if storage.display_index[surface_index] == display.unit_number then
        storage.display_index[surface_index] = nil
    end
end

-- make a key for the display signal cache
---@param signal_name string signal name
---@param quality string? quality of this item
local function make_key(signal_name, quality)
    return signal_name .. (quality and "-" .. quality or "")
end

-- get last signal from a display that was cached or -1 if not found
---@param display LuaEntity display panel
---@param signal string signal name
---@param quality string? quality of this item
---@return integer -1 if not found, else the last signal value
local function get_last_signal(display, signal, quality)
    if not storage.display_signals or not storage.display_signals[display.unit_number] then
        return -1
    end
    local key = make_key(signal, quality)
    return storage.display_signals[display.unit_number][key] or -1
end

-- set the last signal for a display
---@param display LuaEntity display panel
---@param key string signal key
---@param value integer value of the signal
local function set_last_signal(display, key, value)
    if not storage.display_signals or not storage.display_signals[display.unit_number] then
        return
    end
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
        -- Currently asteroids can not be used in rich text
        -- ["asteroid-chunk"] = "asteroid-chunk",
        ["quality"] = "quality",
    }

    return idMap[type]
end

-- handle special signals that require custom logic, such as signal-everything, signal-each, and signal-anything
local function is_special(display, signal_name, value, condition)
    local all = nil
    if signal_name == "signal-everything" then
        all = display.get_signals(defines.wire_connector_id.circuit_green, defines.wire_connector_id.circuit_red)
        if not all then
            return 0
        end
        local sum = 0
        for _, signal in pairs(all) do
            sum = sum + signal.count
        end
        return sum
    end
    if signal_name == "signal-each" then
        all = display.get_signals(defines.wire_connector_id.circuit_green, defines.wire_connector_id.circuit_red)
        return all and #all or 0
    end
    if
        signal_name == "signal-anything"
        and condition
        and condition.first_signal
        and condition.first_signal.name == "signal-anything"
    then
        all = display.get_signals(defines.wire_connector_id.circuit_green, defines.wire_connector_id.circuit_red)
        return all and all[1] and all[1].count or 0
    end
    return value
end

-- update the display with the current signals
function sigd_display.update_display(display)
    local control = display.get_or_create_control_behavior()
    if not control then
        return
    end
    local signal_cache = {}
    local isSpeaker = display.type == "programmable-speaker"
    if isSpeaker then
        local params = display.alert_parameters
        if not params or (params and not params.show_alert) then
            return
        end
        -- Transform into array[DisplayPanelMessageDefinition] as if control was LuaDisplayPanelControlBehavior
        control = {
            messages = {
                { text = params.alert_message, icon = params.icon_signal_id, condition = control.circuit_condition },
            },
        }
    end
    for i, message in pairs(control.messages) do
        local text = message.text
        -- currently the fulfilled value for a display panel is always nil
        -- or (message.condition and message.condition.fulfilled == false)
        if not text then
            goto next_message
        end
        local n = 0
        local updated = false

        -- Update based on icons
        local icon = message.icon
        local icon_name = icon and icon.name or "unset"
        local icon_quality = icon and icon.quality or nil -- can be nil
        local signal = icon_name ~= "unset"
            and display.get_signal(
                icon,
                defines.wire_connector_id.circuit_green,
                defines.wire_connector_id.circuit_red
            )
            or 0
        signal = is_special(display, icon_name, signal, message.condition)

        if signal ~= get_last_signal(display, icon_name, icon_quality) then
            local key = make_key(icon_name, icon_quality)
            signal_cache[key] = signal
            if storage.show_formatted_number then
                signal = flib_format.number(signal, true)
            end
            text, n = text:gsub("%[[%dQRYZEPTGMk %.%-]*%]", "[" .. signal .. "]", 1)
            if n > 0 then
                updated = true
            end
        end

        -- Update based on rich text
        if storage.search_rich_text then
            for typ, value in text:gmatch("%[([%w%-]+)=([%w%-]+)%]") do
                -- Update typ to match SignalIDType
                typ = text_to_signalID(typ)
                if not typ then
                    goto next_match
                end
                signal = display.get_signal(
                    { name = value, type = typ },
                    defines.wire_connector_id.circuit_green,
                    defines.wire_connector_id.circuit_red
                )
                signal = is_special(display, value, signal, message.condition)
                if value ~= icon_name and signal == get_last_signal(display, value) then
                    goto next_match
                end
                local key = make_key(value)
                signal_cache[key] = signal
                if storage.show_formatted_number then
                    signal = flib_format.number(signal, true)
                end

                text, n = text:gsub(
                    "(=" .. value:gsub("%-", "%%-") .. "%])(%[[%dQRYZEPTGMk %.%-]*%])",
                    "%1[" .. signal .. "]",
                    1
                )
                if n > 0 then
                    updated = true
                end
                ::next_match::
            end
            -- we have to do quality separately as there is not way to do optional groups in Lua patterns
            for typ, value, quality in text:gmatch("%[([%w%-]+)=([%w%-]+),quality=([%w%-]+)%]") do
                -- Update typ to match SignalIDType
                typ = text_to_signalID(typ)
                if not typ then
                    goto next_match
                end
                signal = display.get_signal(
                    { name = value, type = typ, quality = quality },
                    defines.wire_connector_id.circuit_green,
                    defines.wire_connector_id.circuit_red
                )
                signal = is_special(display, value, signal, message.condition)

                if
                    value ~= icon_name
                    and quality ~= icon_quality
                    and signal == get_last_signal(display, value, quality)
                then
                    goto next_match
                end
                local key = make_key(value, quality)
                signal_cache[key] = signal
                if storage.show_formatted_number then
                    signal = flib_format.number(signal, true)
                end
                text, n = text:gsub(
                    "(="
                    .. value:gsub("%-", "%%-")
                    .. ",quality="
                    .. quality:gsub("%-", "%%-")
                    .. "%])(%[[%dQRYZEPTGMk %.%-]*%])",
                    "%1[" .. signal .. "]",
                    1
                )
                if n > 0 then
                    updated = true
                end
                ::next_match::
            end
        end
        if updated then
            if not isSpeaker then -- Display Panel
                control.set_message(i, { text = text, icon = icon, condition = message.condition })
            else                  -- Programmable Speaker
                local alert_parameters = display.alert_parameters
                alert_parameters.alert_message = text
                display.alert_parameters = alert_parameters
            end
        end
        ::next_message::
    end
    for key, signal in pairs(signal_cache) do
        set_last_signal(display, key, signal)
    end
end

--- @alias  EntityBuilt EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.on_entity_cloned | EventData.script_raised_revive| EventData.script_raised_built

-- register a new display when built
--- @param e EntityBuilt
function sigd_display.on_display_created(e)
    local display = e.destination or e.entity
    add_display(display)
end

--- @alias  EntityDeleted EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy

-- remove a display when mined or destroyed
--- @param e EntityDeleted
function sigd_display.on_display_deleted(e)
    local display = e.entity
    remove_display(display)
end

sigd_display.add_display = add_display

return sigd_display
