local sigd_display = require("scripts.display")

--- @class sigd_surface
local sigd_surface = {}

-- register all displays on a surface
-- when a new surface is created or the mod is loaded
function sigd_surface.register_surface_displays(surface)
    local displays = surface.find_entities_filtered { type = "display-panel" }
    for _, display in pairs(displays) do
        sigd_display.add_display(display)
    end
end

-- check if a surface has any active players on it (connected)
function sigd_surface.surface_has_players(surface)
    local characters = surface.find_entities_filtered { type = "character" }
    for _, character in pairs(characters) do
        if character.player and character.player.connected and character.player.surface_index == surface.index then
            return true
        end
    end
    return false
end

-- register a new surface when created
--- @param e EventData.on_surface_created|EventData.on_surface_imported
local function on_surface_created(e)
    local surface = game.get_surface(e.surface_index)
    if not surface then return end
    -- create record of that surface
    storage.surfaces[surface.index] = false
    storage.displays[surface.index] = {}
    sigd_surface.register_surface_displays(surface)
    storage.surfaces[surface.index] = sigd_surface.surface_has_players(surface)
end

-- remove a surface when deleted
--- @param e EventData.on_pre_surface_deleted
local function on_surface_deleted(e)
    if not e.surface_index then return end
    storage.surfaces[e.surface_index] = nil
    storage.displays[e.surface_index] = nil
end

-- remove all entities from a cleared surface
--- @param e EventData.on_pre_surface_cleared
local function on_surface_cleared(e)
    if not e.surface_index then return end
    storage.displays[e.surface_index] = nil
    storage.display_index[e.surface_index] = nil
end

sigd_surface.events = {
    [defines.events.on_surface_created] = on_surface_created,
    [defines.events.on_surface_imported] = on_surface_created,
    [defines.events.on_pre_surface_cleared] = on_surface_cleared,
    [defines.events.on_pre_surface_deleted] = on_surface_deleted,
}

return sigd_surface
