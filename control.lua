local circuit_display = {}

-- check if the entity is a display panel
local function validate(entity)
  return entity and entity.type == "display-panel" and entity.valid
end

-- Register a dispaly for updates with the mod
local function add_display(display)
  if not storage.displays then
    storage.displays = {}
  end
  storage.displays[display.unit_number] = display
  storage.display_signals[display.unit_number] = {}
end

-- Remove a display from the mod updates
local function remove_display(display)
  if not storage.displays then return end
  if not display.unit_number then return end
  storage.displays[display.unit_number] = nil
  if not storage.display_signals then return end
  storage.display_signals[display.unit_number] = nil
end

-- get last signal from a dispaly that was cached or -1 if not found
local function get_last_signal(display, signal)
  if not storage.displays or not storage.display_signals then return -1 end
  if not storage.display_signals[display.unit_number] then return -1 end
  return storage.display_signals[display.unit_number][signal] or -1
end

-- update the display with the current signals
local function update_display(display)
  local control = display.get_or_create_control_behavior()
  if not control then return end
  for i, message in pairs(control.messages) do
    local text = message.text
    if not text or (message.condition and message.condition.fulfilled == false) then goto next_message end
    local n = 0
    local updated = false
    -- Update based on icons
    local icon = message.icon
    local icon_name = icon and icon.name or "unset"
    local signal = icon_name ~= "unset" and display.get_signal(icon, defines.wire_connector_id.circuit_green,
      defines.wire_connector_id.circuit_red) or 0
    if signal ~= get_last_signal(display, icon_name) then
      storage.display_signals[display.unit_number][icon_name] = signal
      text, n = text:gsub("%[%d*%]", "[" .. signal .. "]", 1)
      if n > 0 then
        updated = true
      end
    end
    -- Update based on rich text
    if storage.search_rich_text then
      for typ, value in text:gmatch("%[([%w%-]+)=([%w%-]+)]") do
        -- Update typ to match SignalIDType
        if typ == "item" then typ = nil end
        if typ == "virtual-signal" then typ = "virtual" end
        signal = display.get_signal({ name = value, type = typ }, defines.wire_connector_id.circuit_green,
          defines.wire_connector_id.circuit_red)
        if value ~= icon_name and signal == get_last_signal(display, value) then
          goto next_match
        end
        storage.display_signals[display.unit_number][value] = signal
        text, n = text:gsub("(=" .. value:gsub("%-", "%%-") .. "%])(%[%d*%])", "%1[" .. signal .. "]", 1)
        if n > 0 then
          updated = true
        end
        :: next_match ::
      end
    end
    if updated then
      control.set_message(i, { text = text, icon = icon, condition = message.condition })
    end
    :: next_message ::
  end
end

-- each update tick update n dispalys that are on active surfaces
--- @param e EventData.on_tick
function circuit_display.on_tick(e)
  for _ = 1, storage.updates_per_tick, 1 do
    local unit_number, display = nil, nil
    -- find the next display to update (on an active surface)
    repeat
      unit_number, display = next(storage.displays, storage.display_index)
      if unit_number == nil then
        storage.display_index = nil
        return
      end
    until display and storage.surfaces[display.surface.index]
    storage.display_index = unit_number
    if validate(display) then
      update_display(display)
    else
      storage.displays[unit_number] = nil
    end
  end
end

-- register all displays on a surface
-- when a new surface is created or the mod is loaded
local function register_surface_displays(surface)
  local displays = surface.find_entities_filtered { type = "display-panel" }
  for _, display in pairs(displays) do
    if validate(display) then
      add_display(display)
    end
  end
end

-- remove all displays on a surface
-- when a surface is deleted or cleared
local function deregister_surface_displays(surface)
  local displays = surface.find_entities_filtered { type = "display-panel" }
  for _, display in pairs(displays) do
    remove_display(display)
  end
end

-- register the update tick
local function register_events()
  script.on_nth_tick(nil)
  script.on_nth_tick(storage.update_nth_tick, circuit_display.on_tick)
end

function circuit_display.on_init()
  storage.displays = {}
  storage.display_signals = {}
  storage.surfaces = {}
  storage.display_index = nil
  storage.search_rich_text = settings.global["cde-search-rich-text"].value
  --  find any existing displays
  for _, surface in pairs(game.surfaces) do
    register_surface_displays(surface)
    -- create record of that surface
    storage.surfaces[surface.index] = false
  end
  --  set surfaces with active players as active
  for _, player in pairs(game.players) do
    storage.surfaces[player.surface.index] = player.connected
  end
  --  set up the update tick
  storage.updates_per_tick = settings.global["cde-updates-per-tick"].value
  storage.update_nth_tick = settings.global["cde-update-nth-tick"].value
  if storage.update_nth_tick == 1 then
    storage.updates_per_tick = settings.global["cde-updates-per-tick"].value
  else
    storage.updates_per_tick = 1
  end
  register_events()
end

-- check if a surface has any active players on it (connected)
local function surface_has_players(surface)
  local characters = surface.find_entities_filtered { type = "character" }
  for _, character in pairs(characters) do
    if character.player and character.player.connected then
      return true
    end
  end
  return false
end

-- ensure the surface a player is on is active
--- @param e EventData.on_player_joined_game
function circuit_display.on_player_joined_game(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  storage.surfaces[player.surface.index] = true
end

-- check if the surface a player was on still needs to be active
--- @param e EventData.on_player_left_game
function circuit_display.on_player_left_game(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  storage.surfaces[player.surface.index] = surface_has_players(player.surface)
end

-- register a new display when built
--- @param e EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_entity_cloned|EventData.script_raised_revive
function circuit_display.on_display_created(e)
  local display = e.destination or e.entity
  if validate(display) then
    add_display(display)
  end
end

-- remove a display when mined or destroyed
--- @param e EventData.on_pre_player_mined_item|EventData.on_robot_pre_mined|EventData.on_entity_died|EventData.script_raised_destroy|EventData.on_space_platform_pre_mined
function circuit_display.on_display_deleted(e)
  local display = e.entity
  remove_display(display)
end

-- ensure the surface a player is on is active
--- @param e EventData.on_player_created
function circuit_display.on_player_created(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  if not storage.surfaces then
    storage.surfaces = {}
  end
  if not storage.surfaces[player.surface_index] then
    storage.surfaces[player.surface_index] = true
  end
end

-- ensure the surface a player is on is active and the surface the player was on is set correctly
--- @param e EventData.on_player_changed_surface
function circuit_display.on_player_changed_surface(e)
  local player = game.get_player(e.player_index)
  if not player then return end
  if e.surface_index then
    local surface = game.get_surface(e.surface_index)
    if not surface then return end
    -- disable surface if no players are on it
    storage.surfaces[e.surface_index] = surface_has_players(surface)
  else
    -- remove surface if it was removed
    storage.surfaces[e.surface_index] = nil
  end
  -- set current player surface as active
  storage.surfaces[player.surface.index] = true
end

-- update the settings when they are changed
--- @param e EventData.on_runtime_mod_setting_changed
function circuit_display.on_settings_changed(e)
  if not e then return end
  if e.setting == "cde-updates-per-tick" then
    -- only update if the update nth tick is 1
    if storage.update_nth_tick == 1 then
      storage.updates_per_tick = settings.global["cde-updates-per-tick"].value
    else
      storage.updates_per_tick = 1
    end
  end
  if e.setting == "cde-update-nth-tick" then
    storage.update_nth_tick = settings.global["cde-update-nth-tick"].value
    if storage.update_nth_tick == 1 then
      storage.updates_per_tick = settings.global["cde-updates-per-tick"].value
    else
      storage.updates_per_tick = 1
    end
    script.on_nth_tick(nil)
    script.on_nth_tick(storage.update_nth_tick, circuit_display.on_tick)
  end
  if e.setting == "cde-search-rich-text" then
    storage.search_rich_text = settings.global["cde-search-rich-text"].value
  end
end

-- register a new surface when created
--- @param e EventData.on_surface_created
function circuit_display.on_surface_created(e)
  local surface = game.get_surface(e.surface_index)
  if not surface then return end
  storage.surfaces[e.surface_index] = false
  register_surface_displays(surface)
  storage.surfaces[surface.index] = surface_has_players(surface)
end

-- remove a surface when deleted or cleared
--- @param e EventData.on_pre_surface_cleared|EventData.on_pre_surface_deleted
function circuit_display.on_surface_deleted(e)
  if not e.surface_index then return end
  storage.surfaces[e.surface_index] = nil
  deregister_surface_displays(game.get_surface(e.surface_index))
end

local filter = { { filter = 'type', type = 'display-panel' } }

script.on_init(circuit_display.on_init)

script.on_event(defines.events.on_built_entity, circuit_display.on_display_created, filter)
script.on_event(defines.events.on_robot_built_entity, circuit_display.on_display_created, filter)
script.on_event(defines.events.on_entity_cloned, circuit_display.on_display_created, filter)
script.on_event(defines.events.script_raised_revive, circuit_display.on_display_created, filter)
script.on_event(defines.events.on_space_platform_built_entity, circuit_display.on_display_created, filter)

script.on_event(defines.events.on_pre_player_mined_item, circuit_display.on_display_deleted, filter)
script.on_event(defines.events.on_robot_pre_mined, circuit_display.on_display_deleted, filter)
script.on_event(defines.events.on_entity_died, circuit_display.on_display_deleted, filter)
script.on_event(defines.events.script_raised_destroy, circuit_display.on_display_deleted, filter)


script.on_event(defines.events.on_player_joined_game, circuit_display.on_player_joined_game)
script.on_event(defines.events.on_player_left_game, circuit_display.on_player_left_game)

script.on_event(defines.events.on_player_created, circuit_display.on_player_created)

script.on_event(defines.events.on_player_changed_surface, circuit_display.on_player_changed_surface)

script.on_event(defines.events.on_runtime_mod_setting_changed, circuit_display.on_settings_changed)

script.on_event(defines.events.on_surface_created, circuit_display.on_surface_created)
script.on_event({ defines.events.on_pre_surface_cleared, defines.events.on_pre_surface_deleted },
  circuit_display.on_surface_deleted)

-- ensure that the nth tick is set correctly when the mod is loaded
script.on_load(function()
  if not storage then return end
  register_events()
end)

script.on_configuration_changed(function()
  if not storage then return end
  register_events()
end)
