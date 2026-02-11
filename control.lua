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
-- Handle display creation, including cloning and revival
script.on_event(defines.events.on_built_entity, sigd_display.on_display_created, filter)
script.on_event(defines.events.on_robot_built_entity, sigd_display.on_display_created, filter)
script.on_event(defines.events.on_space_platform_built_entity, sigd_display.on_display_created, filter)
script.on_event(defines.events.on_entity_cloned, sigd_display.on_display_created, filter)
script.on_event(defines.events.script_raised_revive, sigd_display.on_display_created, filter)
script.on_event(defines.events.script_raised_built, sigd_display.on_display_created, filter)
-- Handle display deletion, including mining and destruction
script.on_event(defines.events.on_player_mined_entity, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.on_robot_mined_entity, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.on_space_platform_mined_entity, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.on_entity_died, sigd_display.on_display_deleted, filter)
script.on_event(defines.events.script_raised_destroy, sigd_display.on_display_deleted, filter)

-- Capture Display or Speaker GUI closure to ensure it is updated
script.on_event(defines.events.on_gui_closed, function(e)
    if e.entity and e.entity.valid and (e.entity.type == "display-panel" or e.entity.type == "programmable-speaker") then
        -- Invalidate the cache so it forces and update even if signals haven't changed
        -- Player may have removed previous values
        if storage.display_signals and storage.display_signals[e.entity.unit_number] then
            storage.display_signals[e.entity.unit_number] = {}
        end
        sigd_display.update_display(e.entity)
    end
end
)
