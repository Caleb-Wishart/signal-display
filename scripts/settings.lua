local sigd_events = require("scripts.events")

--- @class sigd_settings
local sigd_settings = {}

-- update the settings when they are changed
--- @param e EventData.on_runtime_mod_setting_changed
local function on_settings_changed(e)
    if not e then
        return
    end
    if e.setting == "sigd-updates-per-tick" then
        -- we can only choose to update more than 1 display per tick if we are updating every tick
        if storage.update_every_nth_tick == 1 then
            storage.displays_to_update_per_tick = settings.global["sigd-updates-per-tick"].value
        else
            storage.displays_to_update_per_tick = 1
        end
    end
    if e.setting == "sigd-update-nth-tick" then
        storage.update_every_nth_tick = settings.global["sigd-update-nth-tick"].value
        -- if we are now updating every tick, update the displays_to_update_per_tick to match the setting
        if storage.update_every_nth_tick == 1 then
            storage.displays_to_update_per_tick = settings.global["sigd-updates-per-tick"].value
        else
            storage.displays_to_update_per_tick = 1
        end
        sigd_events.register_events() -- re-register the on_nth_tick event with the new tick rate
    end
    if e.setting == "sigd-search-rich-text" then
        storage.search_rich_text = settings.global["sigd-search-rich-text"].value
    end
    if e.setting == "sigd-show-formatted-number" then
        storage.show_formatted_number = settings.global["sigd-show-formatted-number"].value
    end
end

sigd_settings.events = {
    [defines.events.on_runtime_mod_setting_changed] = on_settings_changed,
}

return sigd_settings
