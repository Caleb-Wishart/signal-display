local sigd_surface = require("scripts.surface")
local sigd_display = require("scripts.display")

--- @class sigd_events
local sigd_events = {}


-- each update tick designated as an update tick n (displays_to_update_per_tick) displays that are on active surfaces
--- @param e EventData.on_tick
local function on_tick(e)
    for _ = 1, storage.displays_to_update_per_tick, 1 do
        local surface_index, active = nil, nil
        -- find the next active surface to update
        repeat
            surface_index, active = next(storage.surfaces, storage.surface_index)
            storage.surface_index = surface_index
            if surface_index == nil then
                return
            end
        until active and storage.displays[surface_index] ~= nil

        local unit_number, display = nil, nil
        -- find the next display to update (on an active surface)
        repeat
            -- In the case the surface is mutated while iterating, we need to check if the surface is still valid
            if storage.displays[surface_index] == nil then
                return
            end
            unit_number, display = next(storage.displays[surface_index], storage.display_index[surface_index])
            storage.display_index[surface_index] = unit_number
            if unit_number == nil then
                return
            end
            -- if the display has become invalid, remove it and reset cursor
            if display and not display.valid then
                storage.displays[surface_index][unit_number] = nil
                storage.display_index[surface_index] = nil
                storage.display_signals[unit_number] = nil
            end
        until display and display.valid and storage.surfaces[display.surface.index]
        sigd_display.update_display(display)
    end
end

-- register the update tick
function sigd_events.register_events()
    script.on_nth_tick(nil) -- clear any existing on_nth_tick handler
    -- update every N ticks, if for some reason the setting is invalid use the default of 2 ticks
    script.on_nth_tick(storage.update_every_nth_tick or 2, on_tick)
end

function sigd_events.on_load()
    if not storage then
        return
    end
    sigd_events.register_events()
end

function sigd_events.on_init()
    storage.displays = {}
    storage.display_signals = {}
    storage.surfaces = {}
    storage.display_index = {}
    storage.surface_index = nil
    storage.search_rich_text = settings.global["sigd-search-rich-text"].value
    storage.show_formatted_number = settings.global["sigd-show-formatted-number"].value

    --  find any existing displays
    for _, surface in pairs(game.surfaces) do
        -- create record of that surface
        storage.surfaces[surface.index] = false
        storage.displays[surface.index] = {}
        sigd_surface.register_surface_displays(surface)
    end
    --  set surfaces with active players as active
    for _, player in pairs(game.players) do
        storage.surfaces[player.surface.index] = player.connected
    end
    --  set up the update tick
    storage.displays_to_update_per_tick = settings.global["sigd-updates-per-tick"].value
    storage.update_every_nth_tick = settings.global["sigd-update-nth-tick"].value
    if storage.update_every_nth_tick == 1 then
        storage.displays_to_update_per_tick = settings.global["sigd-updates-per-tick"].value
    else
        storage.displays_to_update_per_tick = 1
    end
    sigd_events.register_events()
end

return sigd_events
