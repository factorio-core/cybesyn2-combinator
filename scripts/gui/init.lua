local event = require "__0-things__.lib.core.event"
local relm = require "__0-things__.lib.core.relm.relm"
local constants = require "scripts.constants"

-- Import UI component definitions to register elements with Relm
require "scripts.gui.components.main"
require "scripts.gui.components.section_group"
require "scripts.gui.components.encoder_dialog"
require "scripts.gui.components.networks_dialog"
require "scripts.gui.components.settings_tab"

---@class C2CC.Gui
local gui = {}

---Checks if an entity is a Cybersyn 2 Constant Combinator or its ghost.
---@param entity? LuaEntity Entity instance to check.
---@return boolean # True if entity is our combinator or its ghost.
local function is_combinator_entity(entity)
  if not entity or not entity.valid then return false end
  if entity.name == constants.ENTITY_NAME then return true end
  if entity.name == "entity-ghost" and entity.ghost_name == constants.ENTITY_NAME then return true end
  return false
end

---Initializes player GUI event handlers and binds to Factorio GUI lifecycle events.
function gui:init()
  event.bind(defines.events.on_gui_opened, function(ev)
    if ev.entity and ev.entity.valid and is_combinator_entity(ev.entity) then
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
    if root_element and root_element.valid then
      if root_element.name == constants.GUI.MAIN_ELEMENT_NAME then
        self:close(ev.player_index)
      end
    end
  end)
end

-- Compatibility alias for init
gui.register = gui.init

---Opens the main combinator Relm UI window for a player.
---@param player_index integer Factorio player index.
---@param entity LuaEntity The Factorio entity instance.
function gui:open(player_index, entity)
  local player = game.get_player(player_index)
  if not player then return end

  if not entity or not entity.valid then return end

  -- Ensure any existing window is fully closed to prevent duplicates
  self:close(player_index)

  -- Hard destroy any orphaned GUI element with the same name before creating root
  local old_elt = player.gui.screen[constants.GUI.MAIN_ELEMENT_NAME]
  if old_elt and old_elt.valid then
    old_elt.destroy()
  end

  -- Instantiate the Relm UI root element
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
    elt.tags = {
      unit_number = entity.unit_number,
    }
  end

  -- Cache the currently opened entity info to validate lifecycle events
  storage.opened_info = storage.opened_info or {}
  storage.opened_info[player_index] = {
    entity = entity,
    root_id = root_id,
    position = { x = entity.position.x, y = entity.position.y },
    surface_index = entity.surface.index
  }

  player.opened = elt
end

---Destroys and closes the main combinator Relm window for a player.
---@param player_index integer Factorio player index.
function gui:close(player_index)
  -- Release the Relm root memory footprint
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

  local opened_elt = player.opened
  if opened_elt and opened_elt.valid and opened_elt.name == constants.GUI.MAIN_ELEMENT_NAME then
    player.opened = nil
  end

  -- Fallback hard destruction to guarantee cleanup
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
