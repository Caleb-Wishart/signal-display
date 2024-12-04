local flib_migration = require("__flib__.migration")
local sigd_events = require("scripts.events")

local by_version = {
    ["1.1.0"] = function()
        storage.show_formatted_number = true
    end,
    ["1.4.0"] = function()
        storage.display_index = {}
    end,
}

--- @param e ConfigurationChangedData
local function on_configuration_changed(e)
    flib_migration.on_config_changed(e, by_version)
    if not storage then
        return
    end
    sigd_events.register_events()
end

local migrations = {}

migrations.on_configuration_changed = on_configuration_changed

return migrations
