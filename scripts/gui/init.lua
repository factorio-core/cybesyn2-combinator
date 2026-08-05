local event = require "__0-things__.lib.core.event"
local relm = require "__0-things__.lib.core.relm.relm"
local things_client = require "__0-things__.client.client"

local constants = require "scripts.constants"
local utils = require "scripts.gui.utils"
local C2CC = require "scripts.combinator"

-- Import UI component definitions to register elements with Relm
require "scripts.gui.components.main"
require "scripts.gui.components.section_group"
require "scripts.gui.components.group_editor"
require "scripts.gui.components.encoder_dialog"
require "scripts.gui.components.networks_dialog"

---@class C2CC.Gui
local gui = {}

local function is_combinator_entity(entity)
  if not entity or not entity.valid then return false end
  if entity.name == constants.ENTITY_NAME then return true end
  if entity.name == "entity-ghost" and entity.ghost_name == constants.ENTITY_NAME then return true end
  return false
end

---Initializes player GUI event handlers and custom styles.
function gui:init()
  event.bind(defines.events.on_gui_opened, function(ev)
    if ev.entity and ev.entity.valid and is_combinator_entity(ev.entity) then
      local player = game.get_player(ev.player_index)
      if player then
        local thing_id = things_client.get_thing_id(ev.entity)
        self:open(ev.player_index, thing_id, ev.entity)
      end
    end
  end)

  event.bind(defines.events.on_gui_closed, function(ev)
    local player = game.get_player(ev.player_index)
    if not player then return end
    local root_element = player.opened
    if root_element and root_element.valid then
      if root_element.name == "C2CC.Main" then
        self:close(ev.player_index)
      end
    end
  end)

  event.bind(defines.events.on_gui_click, function(ev)
    if ev.element and ev.element.valid and ev.element.name == "c2cc_sort_signals_btn" then
      local player = game.get_player(ev.player_index)
      if player and player.opened and player.opened.valid then
        local root_elt = player.opened
        local thing_id = root_elt.tags and root_elt.tags.thing_id
        local entity = utils.resolve_entity_from_thing(thing_id)
        if entity then
          local comb = C2CC:new(entity, false)
          comb:sort_signals()
          if thing_id then
            utils.force_update_guis_for_thing(thing_id)
          end
        end
      end
    end
  end)
end

gui.register = gui.init

---Opens the main combinator Relm window for a player.
---@param player_index integer Player index.
---@param thing_id? integer 0-things thing ID.
---@param entity? LuaEntity Factorio entity instance.
---@param is_transition? boolean Optional flag if preserving GUI state across ghost transition.
function gui:open(player_index, thing_id, entity, is_transition)
  local player = game.get_player(player_index)
  if not player then return end

  if not entity or not entity.valid then
    entity = utils.resolve_entity_from_thing(thing_id)
  end
  if not entity or not entity.valid then return end

  local comb = C2CC:new(entity, false)
  local default_prio = utils.get_default_priority()
  if comb:get_priority() == 0 and default_prio ~= 0 then
    comb:set_priority(default_prio)
  end

  local default_net = utils.get_default_network_flag()
  local net_sigs = comb:get_network_signals()
  if #net_sigs == 0 and default_net ~= 0 then
    comb:set_network_signals({ { signal = { type = "virtual", name = "signal-A" }, count = default_net } })
  end

  local grps = comb:get_groups()
  if #grps == 0 then
    comb:add_group("")
  end

  self:close(player_index)

  local gs = utils.get_gui_state(player_index)
  local default_stks = utils.get_default_stacks(player_index)
  local default_cnt = utils.get_default_count(player_index)

  if not is_transition then
    gs.edit_stacks_text = default_stks
    gs.edit_items_text = default_cnt
    gs.selected_section = nil
    gs.selected_slot = nil
  end

  local focus_target = "c2cc_edit_stacks"
  if default_cnt ~= "" and default_stks == "" then
    focus_target = "c2cc_edit_count"
  else
    focus_target = "c2cc_edit_stacks"
  end

  local root_id, elt = relm.root_create(
    player.gui.screen,
    "C2CC.Main",
    "C2CC.Main",
    {
      entity = entity,
      thing_id = thing_id,
      player_index = player_index,
    }
  )

  if elt and elt.valid then
    elt.tags = {
      unit_number = entity.unit_number,
      thing_id = thing_id,
    }
  end

  if thing_id then
    utils.set_gui_root(thing_id, player_index, root_id)
  end

  storage.opened_info[player_index] = {
    entity = entity,
    surface_index = entity.surface.index,
    position = { x = entity.position.x, y = entity.position.y }
  }

  player.opened = elt
  if not is_transition then
    utils.focus_input_field(player_index, focus_target)
  end
end

---Closes the main combinator Relm window for a player.
---@param player_index integer Player index.
function gui:close(player_index)
  if storage.opened_info then
    storage.opened_info[player_index] = nil
  end

  local player = game.get_player(player_index)
  if not player then return end

  local opened_elt = player.opened
  if opened_elt and opened_elt.valid and opened_elt.name == "C2CC.Main" then
    player.opened = nil
  end

  local tracker = utils.get_gui_tracker()
  for thing_id, by_player in pairs(tracker) do
    local root_id = by_player[player_index]
    if root_id then
      relm.root_destroy(root_id)
      by_player[player_index] = nil
    end
  end

  local children = player.gui.screen.children
  if children then
    for _, child in ipairs(children) do
      if child.name == "C2CC.Main" then
        child.destroy()
      end
    end
  end
end

return gui
