require "util"
local event = require "__0-things__.lib.core.event"
local things_client = require "__0-things__.client.client"

local gui = require "scripts.gui"
local C2CC = require "scripts.combinator"
local constants = require "scripts.constants"

-- Bootstrap Relm with core events
local relm = require "__0-things__.lib.core.relm.relm"
relm.bootstrap_with_core_events(event)

gui:init()

---Ensures all required storage structures (including 0-things and Relm internal storage) are initialized.
local function init_storage()
  -- Internal storage container for the Relm UI framework (roots, counter, object destruction mapping).
  storage._relm = storage._relm or { roots = {}, root_counter = 0, reg_num_map = {} }

  -- Internal storage containers for 0-things event system (dynamic event bindings).
  storage._event_id = storage._event_id or 0
  storage._event = storage._event or {}

  -- Per-player active draft UI state (input text, active network mask, and selected slot).
  storage.gui_state = storage.gui_state or {}

  -- Per-player info on currently opened combinators/ghosts for O(1) validity checking and seamless ghost-to-real transitions.
  storage.opened_info = storage.opened_info or {}

  -- Relm GUI root handle tracker mapping 0-things thing_id -> player_index -> root_id.
  storage.gui_tracker = storage.gui_tracker or {}
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)

---Checks if an entity is a Cybersyn 2 Constant Combinator or its ghost.
---@param entity? LuaEntity Entity instance to check.
---@return boolean # True if entity is a combinator or its ghost.
local function is_combinator_entity(entity)
  if not entity or not entity.valid then return false end
  if entity.name == constants.ENTITY_NAME then return true end
  if entity.name == "entity-ghost" and entity.ghost_name == constants.ENTITY_NAME then return true end
  return false
end

-- Entity copy-paste event handling
event.bind(defines.events.on_entity_settings_pasted, function(ev)
  local src = ev.source
  local dest = ev.destination
  if src and src.valid and dest and dest.valid and is_combinator_entity(dest) then
    if is_combinator_entity(src) then
      local dest_comb = C2CC:new(dest)
      local src_comb = C2CC:new(src)
      if dest_comb and src_comb then
        dest_comb:copy_from(src_comb)
      end
    end

    local player = game.get_player(ev.player_index)
    if player and player.opened and player.opened.valid and player.opened.name == "C2CC.Main" then
      local thing_id = things_client.get_thing_id(dest)
      gui:open(ev.player_index, thing_id, dest)
    end
  end
end)

---Handles ghost revival / building into a real entity to seamlessly transition open GUIs.
---@param ev table Event data object.
local function handle_entity_built_or_revived(ev)
  local new_entity = ev.entity or ev.created_entity
  if not new_entity or not new_entity.valid or not is_combinator_entity(new_entity) then return end
  if not storage.opened_info then return end

  for player_index, info in pairs(storage.opened_info) do
    if info and info.surface_index == new_entity.surface.index then
      if math.abs(info.position.x - new_entity.position.x) < 0.01 and math.abs(info.position.y - new_entity.position.y) < 0.01 then
        local thing_id = things_client.get_thing_id(new_entity)
        gui:open(player_index, thing_id, new_entity, true)
      end
    end
  end
end

event.bind(defines.events.on_built_entity, handle_entity_built_or_revived)
event.bind(defines.events.on_robot_built_entity, handle_entity_built_or_revived)
event.bind(defines.events.on_post_entity_died, handle_entity_built_or_revived)
event.bind(defines.events.script_raised_revive, handle_entity_built_or_revived)
event.bind(defines.events.script_raised_built, handle_entity_built_or_revived)

---Checks and closes open GUIs when their associated entity is mined or destroyed.
---@param ev? table Event payload table.
local function check_and_close_invalid_guis(ev)
  if not storage.opened_info then return end
  local mined_entity = ev and (ev.entity or ev.created_entity)
  for player_index, info in pairs(storage.opened_info) do
    if not info.entity or not info.entity.valid or (mined_entity and mined_entity == info.entity) then
      gui:close(player_index)
    end
  end
end

event.bind(defines.events.on_player_mined_entity, check_and_close_invalid_guis)
event.bind(defines.events.on_robot_mined_entity, check_and_close_invalid_guis)
event.bind(defines.events.on_entity_died, check_and_close_invalid_guis)
event.bind(defines.events.script_raised_destroy, check_and_close_invalid_guis)
