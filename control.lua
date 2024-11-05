local flib_format = require("__flib__.format")
local flib_migration = require("__flib__.migration")

local circuit_display = {}

-- Function to extract all attributes from a rich text string
local function parseRichText(text)
  local parts = {}
  local currentSearchText = text

  -- Trim the string until done
  while currentSearchText ~= nil and #currentSearchText > 0 do
    -- Get the next x=y parameter
    local paramStart, paramEnd = string.find(currentSearchText, "[%w%-]+=[%w%-]+")

    -- Nothing found so string is done
    if (paramStart == nil or paramEnd == nil) then
      currentSearchText = nil
      break
    end

    -- Extract key and value and store it
    local currentParam = string.sub(currentSearchText, paramStart, paramEnd)
    for key, value in string.gmatch(currentParam, "([%w%-]+)=([%w%-]+)") do
      parts[key] = value
    end

    -- Trim text by the part we just extracted
    currentSearchText = string.sub(currentSearchText, paramEnd + 1, #currentSearchText)
  end

  return parts
end


-- Function to find all the rich texts inside a display string
local function parseDisplayText(text)
  local richTexts = {}
  local currentSearchText = text

  -- Search the text until done
  while (currentSearchText ~= nil and #currentSearchText > 0) do
    -- Strip the next rich text tag out e.g [item=rocket-turret,quality=rare]
    local signalStart, signalEnd = string.find(currentSearchText, "%[[%w%-=,]+%]")

    -- No rich text found, nothing left to do
    if (signalStart == nil or signalEnd == nil) then
      currentSearchText = nil
      break
    end

    -- Extract the rich text and parse it
    local currentSignal = string.sub(currentSearchText, signalStart, signalEnd)
    table.insert(richTexts, parseRichText(currentSignal))

    -- Trim text by the part we just extraced
    currentSearchText = string.sub(currentSearchText, signalEnd + 1, #currentSearchText)
  end

  return richTexts
end

-- Function to be lazy and extend if any other signals need converting from one value to another
local function convert(text)
  local conversionTable = {
    ["virtual-signal"] = "virtual",
  }

  if conversionTable[text] ~= nil then
    return conversionTable[text]
  end

  return text
end

-- Function to find the prototype type of a given parsed rich text
local function getType(params)
  local types = {
    "item",
    "fluid",
    "virtual-signal",
    "entity",
    "recipe",
    "space-location",
    "asteroid-chunk",
    "planet"
  }

  for _, value in pairs(types) do
    if params[value] ~= null then
      return value
    end
  end

  return nil
end

-- check if the entity is a display panel
local function validate(entity)
  return entity and entity.type == "display-panel" and entity.valid
end

-- Register a dispaly for updates with the mod
local function add_display(display)
  local surface_index = display.surface.index
  if not storage.displays then
    storage.displays = {}
  end

  if not storage.displays[surface_index] then
    storage.displays[surface_index] = {}
  end

  storage.displays[surface_index][display.unit_number] = display
  storage.display_signals[display.unit_number] = {}
end

-- Remove a display from the mod updates
local function remove_display(display)
  if not display.unit_number or not display.surface then return end
  if not storage.displays then return end

  local surface_index = display.surface.index
  if not storage.displays[surface_index] then return end
  storage.displays[surface_index][display.unit_number] = nil

  if not storage.display_signals then return end
  storage.display_signals[display.unit_number] = nil

  -- if this was the last display on the surface, restart from begining
  if storage.display_index[surface_index] == display.unit_number then
    storage.display_index[surface_index] = nil
  end
end

-- get last signal from a dispaly that was cached or -1 if not found
local function get_last_signal(display, signal)
  if not storage.display_signals or not storage.display_signals[display.unit_number] then
    return -1
  end
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
      if storage.show_formatted_number then
        signal = flib_format.number(signal, true, 3)
      end
      text, n = text:gsub("%[[%dQRYZEPTGMk %.]*%]", "[" .. signal .. "]", 1)
      if n > 0 then
        updated = true
      end
    end

    -- Update based on rich text
    if storage.search_rich_text then
      -- Parse the current line in to Rich Text blocks
      local richTexts = parseDisplayText(text)

      for _, richText in pairs(richTexts) do
        -- Extract the type and value
        local typ = getType(richText)
        local value = richText[typ]

        -- Not rich text, so skip it
        if (typ == nil or value == nil) then
          goto next_match
        end

        -- Ensure type is correct
        typ = convert(typ)

        -- Initialise variables that can change based on Quality
        local getSignalParams = {
          name = value,
          type = typ
        }
        local signalKey = value

        -- Add quality in if detected
        if (richText["quality"] ~= nil) then
          getSignalParams["quality"] = richText["quality"]
          signalKey = signalKey .. ",quality=" .. richText["quality"]
        end


        signal = display.get_signal(getSignalParams,
          defines.wire_connector_id.circuit_green,
          defines.wire_connector_id.circuit_red)

        storage.display_signals[display.unit_number][signalKey] = signal
        if storage.show_formatted_number then
          signal = flib_format.number(signal, true, 3)
        end

        text, n = text:gsub("(=" .. signalKey:gsub("%-", "%%-") .. "%])(%[[%dQRYZEPTGMk %.]*%])", "%1[" .. signal .. "]",
          1)
        if n > 0 then
          updated = true
        end
        :: next_match ::
      end
      if updated then
        control.set_message(i, { text = text, icon = icon, condition = message.condition })
      end
    end
    :: next_message ::
  end
end

-- each update tick update n dispalys that are on active surfaces
--- @param e EventData.on_tick
function circuit_display.on_tick(e)
  for _ = 1, storage.updates_per_tick, 1 do
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
      unit_number, display = next(storage.displays[surface_index], storage.display_index[surface_index])
      storage.display_index[surface_index] = unit_number
      if unit_number == nil then
        return
      end
    until display and storage.surfaces[display.surface.index]
    update_display(display)
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

-- register the update tick
local function register_events()
  script.on_nth_tick(nil)
  script.on_nth_tick(storage.update_nth_tick, circuit_display.on_tick)
end

function circuit_display.on_init()
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
    register_surface_displays(surface)
  end
  --  set surfaces with active players as active
  for _, player in pairs(game.players) do
    storage.surfaces[player.surface.index] = player.connected
  end
  --  set up the update tick
  storage.updates_per_tick = settings.global["sigd-updates-per-tick"].value
  storage.update_nth_tick = settings.global["sigd-update-nth-tick"].value
  if storage.update_nth_tick == 1 then
    storage.updates_per_tick = settings.global["sigd-updates-per-tick"].value
  else
    storage.updates_per_tick = 1
  end
  register_events()
end

-- check if a surface has any active players on it (connected)
local function surface_has_players(surface)
  local characters = surface.find_entities_filtered { type = "character" }
  for _, character in pairs(characters) do
    if character.player and character.player.connected and character.player.surface_index == surface.index then
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
    script.on_nth_tick(nil)
    script.on_nth_tick(storage.update_nth_tick, circuit_display.on_tick)
  end
  if e.setting == "sigd-search-rich-text" then
    storage.search_rich_text = settings.global["sigd-search-rich-text"].value
  end
  if e.setting == "sigd-show-formatted-number" then
    storage.show_formatted_number = settings.global["sigd-show-formatted-number"].value
  end
end

-- register a new surface when created
--- @param e EventData.on_surface_created
function circuit_display.on_surface_created(e)
  local surface = game.get_surface(e.surface_index)
  if not surface then return end
  -- create record of that surface
  storage.surfaces[surface.index] = false
  storage.displays[surface.index] = {}
  register_surface_displays(surface)
  storage.surfaces[surface.index] = surface_has_players(surface)
end

-- remove a surface when deleted or cleared
--- @param e EventData.on_pre_surface_cleared|EventData.on_pre_surface_deleted
function circuit_display.on_surface_deleted(e)
  if not e.surface_index then return end
  storage.surfaces[e.surface_index] = nil
  storage.displays[e.surface_index] = nil
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

local migrations_by_version = {
  ["1.1.0"] = function()
    storage.show_formatted_number = true
  end,
}

script.on_configuration_changed(function(e)
  flib_migration.on_config_changed(e, migrations_by_version)
  if not storage then return end
  register_events()
end)
