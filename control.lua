local handler = require("__core__.lualib.event_handler")
local sigd_display = require("scripts.display")

handler.add_libraries({
    require("scripts.migrations"),

    require("scripts.events"),
    require("scripts.settings"),
    require("scripts.surface"),
    require("scripts.player"),
})

-- The Event Handler library does not support events with filters, so we have to use the vanilla API for these events.

local filter =
    { { filter = "type", type = "display-panel" }, { mode = "or", filter = "type", type = "programmable-speaker" } }
script.on_event(defines.events.on_built_entity, sigd_display.on_display_created, filter)
script.on_event(defines.events.on_robot_built_entity, sigd_display.on_display_created, filter)
script.on_event(defines.events.on_space_platform_built_entity, sigd_display.on_display_created, filter)
script.on_event(defines.events.on_entity_cloned, sigd_display.on_display_created, filter)
script.on_event(defines.events.script_raised_revive, sigd_display.on_display_created, filter)
script.on_event(defines.events.script_raised_built, sigd_display.on_display_created, filter)

script.on_event(defines.events.on_player_mined_entity, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.on_robot_mined_entity, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.on_space_platform_mined_entity, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.on_entity_died, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.script_raised_destroy, sigd_display.on_display_deleted, filter)
