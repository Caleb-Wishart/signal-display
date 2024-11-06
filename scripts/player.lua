local sigd_surfcace = require("scripts.surface")

--- @class sigd_player
local sigd_player = {}

-- ensure the surface a player is on is active
--- @param e EventData.on_player_created
local function on_player_created(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if not storage.surfaces then
        storage.surfaces = {}
    end
    if not storage.surfaces[player.surface_index] then
        storage.surfaces[player.surface_index] = true
    end
end

-- ensure the surface a player is on is active and the surface the player was on is set correctly if it exists
--- @param e EventData.on_player_changed_surface
local function on_player_changed_surface(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    if e.surface_index then
        local surface = game.get_surface(e.surface_index)
        if not surface then return end
        -- disable surface if no players are on it
        storage.surfaces[e.surface_index] = sigd_surfcace.surface_has_players(surface)
    end
    -- set current player surface as active
    storage.surfaces[player.surface.index] = true
end

-- ensure the surface a player is on is active
--- @param e EventData.on_player_joined_game
local function on_player_joined_game(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    storage.surfaces[player.surface.index] = true
end

-- check if the surface a player was on still needs to be active
--- @param e EventData.on_player_left_game
local function on_player_left_game(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    storage.surfaces[player.surface.index] = sigd_surfcace.surface_has_players(player.surface)
end

sigd_player.events = {
    [defines.events.on_player_created] = on_player_created,
    [defines.events.on_player_changed_surface] = on_player_changed_surface,
    [defines.events.on_player_joined_game] = on_player_joined_game,
    [defines.events.on_player_left_game] = on_player_left_game,
}

return sigd_player
