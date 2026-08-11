local event = require("__cybersyn2-combinator__/lib/core/event")
local relm = require("__cybersyn2-combinator__/lib/core/relm/relm")
local constants = require "scripts.constants"
local utils = require "scripts.gui.utils"
local priorities = require "scripts.gui.priorities"

require "scripts.gui.components.main"
require "scripts.gui.components.section_group"
require "scripts.gui.components.encoder_dialog"
require "scripts.gui.components.networks_dialog"
require "scripts.gui.components.settings_tab"
require "scripts.gui.components.priorities_summary"

---@class C2CC.Gui
local gui = {}

function gui:init()
  event.bind(defines.events.on_gui_opened, function(ev)
    if ev.entity and ev.entity.valid and utils.is_combinator_entity(ev.entity) then
      local player = game.get_player(ev.player_index)
      if player then
        self:open(ev.player_index, ev.entity)
      end
    end
  end)

  event.bind(defines.events.on_gui_closed, function(ev)
    local player = game.get_player(ev.player_index)
    if not player then return end
    local root_element = player.opened
    if root_element and root_element.valid and root_element.name == constants.GUI.MAIN_ELEMENT_NAME then
      self:close(ev.player_index)
    end
  end)
end

gui.register = gui.init

function gui:open(player_index, entity)
  local player = game.get_player(player_index)
  if not player then return end
  if not entity or not entity.valid then return end

  self:close(player_index)

  local old_elt = player.gui.screen[constants.GUI.MAIN_ELEMENT_NAME]
  if old_elt and old_elt.valid then
    old_elt.destroy()
  end

  storage._relm = storage._relm or { roots = {}, root_counter = 0, reg_num_map = {} }
  storage._counters = storage._counters or {}
  storage._sched = storage._sched or { tasks = {}, at = {} }
  storage._event_id = storage._event_id or 0
  storage._event = storage._event or {}
  storage._event_subtick = storage._event_subtick or {}

  local root_id, elt = relm.root_create(
    player.gui.screen,
    constants.GUI.MAIN_ELEMENT_NAME,
    constants.GUI.MAIN_ELEMENT_NAME,
    {
      entity = entity,
      player_index = player_index,
    }
  )

  if elt and elt.valid then
    elt.tags = { unit_number = entity.unit_number }
  end

  local target_stop_unit, target_inv_ids = priorities.find_station_for_combinator(entity)

  storage.opened_info = storage.opened_info or {}
  storage.opened_info[player_index] = {
    entity = entity,
    root_id = root_id,
    target_stop_unit = target_stop_unit,
    target_inv_ids = target_inv_ids,
    position = { x = entity.position.x, y = entity.position.y },
    surface_index = entity.surface.index,
  }

  player.opened = elt
end

function gui:close(player_index)
  local info = storage.opened_info and storage.opened_info[player_index]
  if info and info.root_id then
    relm.root_destroy(info.root_id)
  end

  if storage.opened_info then
    storage.opened_info[player_index] = nil
  end

  if storage.gui_state then
    storage.gui_state[player_index] = nil
  end

  local player = game.get_player(player_index)
  if not player then return end

  player.opened = nil

  local children = player.gui.screen.children
  if children then
    for _, child in ipairs(children) do
      if child.name == constants.GUI.MAIN_ELEMENT_NAME then
        child.destroy()
      end
    end
  end
end

return gui
