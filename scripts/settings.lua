local sigd_events = require("scripts.events")

--- @class sigd_settings
local sigd_settings = {}

-- update the settings when they are changed
--- @param e EventData.on_runtime_mod_setting_changed
local function on_settings_changed(e)
    if not e then return end
    if e.setting == "sigd-updates-per-tick" then
        -- only update if the update nth tick is 1
        if storage.update_nth_tick == 1 then
            storage.updates_per_tick = settings.global["sigd-updates-per-tick"].value
        else
            storage.updates_per_tick = 1
        end
    end
    if e.setting == "sigd-update-nth-tick" then
        storage.update_nth_tick = settings.global["sigd-update-nth-tick"].value
        if storage.update_nth_tick == 1 then
            storage.updates_per_tick = settings.global["sigd-updates-per-tick"].value
        else
            storage.updates_per_tick = 1
        end
        sigd_events.register_events()
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
