local sigd_events = require("scripts.events")

local by_version = {
    ["1.1.0"] = function ()
        storage.show_formatted_number = true
    end,
    ["1.4.0"] = function ()
        storage.display_index = {}
    end,
    ["1.5.1"] = function ()
        -- Reset display_index to fix a bug with the display_index not being
        -- updated when a service is removed and that surface index is reused
        storage.display_index = {}
    end,
    ["1.5.2"] = function ()
        -- handle internal variable renames
        storage.displays_to_update_per_tick = storage.updates_per_tick or 1
        storage.updates_per_tick = nil

        storage.update_every_nth_tick = storage.update_nth_tick or 1
        storage.update_nth_tick = nil
    end
}

local migrations = {}

---@param e ConfigurationChangedData
function migrations.on_configuration_changed(e)
    local _mod_changes = e.mod_changes and e.mod_changes[script.mod_name]
    if not _mod_changes then
        return
    end
    local old_version = _mod_changes.old_version
    if not old_version then
        return
    end

    for version, migration in pairs(by_version) do
        if helpers.compare_versions(old_version, version) < 0 then
            migration()
        end
    end

    if not storage then
        return
    end
    sigd_events.register_events()
end

return migrations
