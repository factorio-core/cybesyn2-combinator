require "util"
local event = require "__0-things__.lib.core.event"
local relm = require "__0-things__.lib.core.relm.relm"

local gui = require "scripts.gui"
local utils = require "scripts.gui.utils"
local C2CC = require "scripts.models.combinator"
local constants = require "scripts.constants"

-- Bootstrap Relm with core 0-things events to manage GUI roots
relm.bootstrap_with_core_events(event)
gui:init()

---Ensures all required storage structures (including 0-things and Relm internal storage) are initialized.
local function init_storage()
  -- Internal storage container for 0-things counter system.
  storage._counters = storage._counters or {}

  -- Internal storage container for 0-things scheduler system.
  storage._sched = storage._sched or { tasks = {}, at = {} }
  storage._sched.tasks = storage._sched.tasks or {}
  storage._sched.at = storage._sched.at or {}

  -- Internal storage container for the Relm UI framework (roots, counter, object destruction mapping).
  storage._relm = storage._relm or { roots = {}, root_counter = 0, reg_num_map = {} }

  -- Internal storage containers for 0-things event system (dynamic event bindings).
  storage._event_id = storage._event_id or 0
  storage._event = storage._event or {}
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

---Handles entity built / revived events to initialize defaults and seamlessly transition open GUIs.
---@param ev table Event data object.
local function handle_entity_built_or_revived(ev)
  local new_entity = ev and (ev.entity or ev.created_entity)
  if not new_entity or not new_entity.valid or not is_combinator_entity(new_entity) then return end

  local comb = C2CC:New(new_entity)
  local tags = ev.tags
  comb:InitializeDefaults(tags and tags.from_blueprint or false, ev.player_index)

  if storage.opened_info then
    for player_index, info in pairs(storage.opened_info) do
      if info and info.position and info.surface_index == new_entity.surface.index then
        if math.abs(info.position.x - new_entity.position.x) < 0.01 and math.abs(info.position.y - new_entity.position.y) < 0.01 then
          gui:open(player_index, new_entity)
        end
      end
    end
  end
end

event.bind(defines.events.on_built_entity, handle_entity_built_or_revived)
event.bind(defines.events.on_robot_built_entity, handle_entity_built_or_revived)
event.bind(defines.events.on_post_entity_died, handle_entity_built_or_revived)
event.bind(defines.events.script_raised_revive, handle_entity_built_or_revived)
event.bind(defines.events.script_raised_built, handle_entity_built_or_revived)

-- Entity copy-paste event handling
event.bind(defines.events.on_entity_settings_pasted, function(ev)
  local src = ev.source
  local dest = ev.destination
  if src and src.valid and dest and dest.valid and is_combinator_entity(dest) then
    local dest_comb = C2CC:New(dest)
    if is_combinator_entity(src) then
      local src_comb = C2CC:New(src)
      if dest_comb and src_comb then
        dest_comb:CopyFrom(src_comb)
      end
    else
      dest_comb:FixPastedVanillaSections(ev.player_index)
    end

    local player = game.get_player(ev.player_index)
    if player and player.opened and player.opened.valid and player.opened.name == constants.GUI.MAIN_ELEMENT_NAME then
      gui:open(ev.player_index, dest)
    end
  end
end)
