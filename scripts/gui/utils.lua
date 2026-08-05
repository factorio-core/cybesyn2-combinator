local relm = require "__0-things__.lib.core.relm.relm"
local things_client = require "__0-things__.client.client"
local constants = require "scripts.constants"
local C2CC = require "scripts.combinator"

---@class C2CC.GuiUtils
local utils = {}

---Converts any numeric value to a signed 32-bit integer.
---@param val any Number or string representation to convert.
---@return integer # The clamped signed 32-bit integer (-2147483648 to 2147483647).
function utils.to_int32(val)
  val = tonumber(val) or 0
  if val > 2147483647 then
    if val <= 4294967295 then
      return math.floor(val - 4294967296)
    else
      return 2147483647
    end
  elseif val < -2147483648 then
    return -2147483648
  end
  return math.floor(val)
end

---Formats a number into a short string representation with unit suffixes (e.g., 1.5k, 2M, 10G).
---@param n? number|string The number or numeric string to format.
---@return string # The short formatted string representation.
function utils.format_short_number(n)
  local num = tonumber(n)
  if not num or num == 0 then return "0" end
  local abs_n = math.abs(num)
  local sign_str = num < 0 and "-" or ""
  if abs_n >= 1000000000 then
    local formatted = string.format("%.1f", abs_n / 1000000000):gsub("%.0$", "")
    return sign_str .. formatted .. "G"
  elseif abs_n >= 1000000 then
    local formatted = string.format("%.1f", abs_n / 1000000):gsub("%.0$", "")
    return sign_str .. formatted .. "M"
  elseif abs_n >= 1000 then
    local formatted = string.format("%.1f", abs_n / 1000):gsub("%.0$", "")
    return sign_str .. formatted .. "k"
  else
    return tostring(num)
  end
end

---Retrieves the GUI root tracker storage table.
---@return table<integer, table<integer, Relm.RootId>> # Mapping of thing_id -> player_index -> root_id.
function utils.get_gui_tracker()
  storage.gui_tracker = storage.gui_tracker or {}
  return storage.gui_tracker
end

---Scans all active combinators and ghosts in the world and gathers unique network signals.
---@return table<string, { signal: SignalID, count: integer }> # Map of network signal key to signal data.
function utils.get_all_global_active_networks()
  local result = {}

  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered { name = constants.ENTITY_NAME }
    local ghosts = surface.find_entities_filtered { name = "entity-ghost", ghost_name = constants.ENTITY_NAME }

    for _, entity_list in ipairs({ entities, ghosts }) do
      for _, entity in ipairs(entity_list) do
        if entity and entity.valid then
          local comb = C2CC:new(entity, false)
          local net_sigs = comb:get_network_signals()
          for _, nsig in ipairs(net_sigs) do
            if nsig.signal and nsig.signal.name then
              local key = nsig.signal.name .. "_" .. tostring(nsig.count)
              result[key] = { signal = nsig.signal, count = nsig.count }
            end
          end
        end
      end
    end
  end

  return result
end

---Scans all active combinators and ghosts in the world and returns a sorted list of unique group names.
---@return string[] # Sorted array of unique group name strings.
function utils.get_all_global_group_names()
  local group_set = {}

  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered { name = constants.ENTITY_NAME }
    local ghosts = surface.find_entities_filtered { name = "entity-ghost", ghost_name = constants.ENTITY_NAME }

    for _, entity_list in ipairs({ entities, ghosts }) do
      for _, entity in ipairs(entity_list) do
        if entity and entity.valid then
          local comb = C2CC:new(entity, false)
          local grps = comb:get_groups()
          for _, g in ipairs(grps) do
            if g.raw_group_name and g.raw_group_name ~= "" then
              group_set[g.raw_group_name] = true
            end
          end
        end
      end
    end
  end

  local result = {}
  for gname, _ in pairs(group_set) do
    table.insert(result, gname)
  end
  table.sort(result)
  return result
end

---Registers a Relm GUI root ID for a thing and player.
---@param thing_id integer The thing ID.
---@param player_index integer Player index.
---@param root_id Relm.RootId Relm root ID.
function utils.set_gui_root(thing_id, player_index, root_id)
  local tracker = utils.get_gui_tracker()
  if not tracker[thing_id] then tracker[thing_id] = {} end
  tracker[thing_id][player_index] = root_id
end

---Forces a repaint of all open Relm GUIs for a specific thing ID.
---@param thing_id integer The thing ID to repaint GUIs for.
function utils.force_update_guis_for_thing(thing_id)
  local tracker = utils.get_gui_tracker()
  local by_player = tracker[thing_id]
  if not by_player then return end
  for _, root_id in pairs(by_player) do
    if root_id then
      local handle = relm.root_handle(root_id)
      if handle then relm.paint(handle) end
    end
  end
end

---Destroys all active Relm GUIs for a given thing ID.
---@param thing_id integer The thing ID.
function utils.destroy_guis_for_thing(thing_id)
  local tracker = utils.get_gui_tracker()
  local by_player = tracker[thing_id]
  if not by_player then return end
  for _, root_id in pairs(by_player) do
    if root_id then relm.root_destroy(root_id) end
  end
  tracker[thing_id] = nil
end

---Resolves a valid LuaEntity from a 0-things thing ID.
---@param thing_id? integer The thing ID.
---@return LuaEntity? # The resolved Factorio entity, or nil if invalid.
function utils.resolve_entity_from_thing(thing_id)
  if not thing_id then return nil end
  local ct = things_client.get(thing_id)
  if ct and ct.last_entity and ct.last_entity.valid then
    return ct.last_entity
  end
  return nil
end

---Checks whether a signal is stackable (items only, not fluids or virtual signals).
---@param signal? SignalID The signal prototype.
---@return boolean # True if the signal is an item with stack size > 1.
function utils.is_stackable_signal(signal)
  if not signal or not signal.name then return false end
  if signal.type == "fluid" or signal.type == "virtual" or signal.type == "quality" then
    return false
  end
  return true
end

---Gets the item stack size for a given signal.
---@param signal? SignalID The signal prototype.
---@return integer # Stack size (defaults to 1 for fluids/virtuals).
function utils.get_stack_size(signal)
  if not signal or not signal.name then return 1 end
  if not utils.is_stackable_signal(signal) then return 1 end
  local proto = prototypes.item[signal.name]
  return proto and proto.stack_size or 1
end

---Checks whether negative signals are enabled in player settings.
---@param player_index integer Player index.
---@return boolean # True if negative signals are enabled.
function utils.is_negative_signals_enabled(player_index)
  local psettings = settings.get_player_settings(player_index)
  return psettings and psettings[constants.SETTINGS.NEGATIVE_SIGNALS] and psettings[constants.SETTINGS.NEGATIVE_SIGNALS].value
end

---Gets default priority from global settings.
---@return integer # Default priority number.
function utils.get_default_priority()
  local setting = settings.global and settings.global[constants.SETTINGS.PRIORITY]
  return setting and tonumber(setting.value) or constants.SETTINGS.DEFAULT_PRIORITY
end

---Gets default network flag from global settings.
---@return integer # Default network flag bitmask.
function utils.get_default_network_flag()
  local setting = settings.global and settings.global[constants.SETTINGS.NETWORK_FLAG]
  return setting and tonumber(setting.value) or constants.SETTINGS.DEFAULT_NETWORK_FLAG
end

---Gets default stacks text setting for a player.
---@param player_index integer|LuaPlayer Player index or instance.
---@return string # Default stacks text.
function utils.get_default_stacks(player_index)
  if not player_index then return "" end
  local player = type(player_index) == "number" and game.get_player(player_index) or player_index
  if not player or not player.valid then return "" end
  local psettings = settings.get_player_settings(player)
  local setting = psettings and psettings[constants.SETTINGS.STACKS]
  local val = setting and tonumber(setting.value) or 0
  return val ~= 0 and tostring(val) or ""
end

---Gets default count text setting for a player.
---@param player_index integer|LuaPlayer Player index or instance.
---@return string # Default count text.
function utils.get_default_count(player_index)
  if not player_index then return "" end
  local player = type(player_index) == "number" and game.get_player(player_index) or player_index
  if not player or not player.valid then return "" end
  local psettings = settings.get_player_settings(player)
  local setting = psettings and psettings[constants.SETTINGS.COUNT]
  local val = setting and tonumber(setting.value) or 0
  return val ~= 0 and tostring(val) or ""
end

---Gets or initializes player GUI persistent state from storage.
---@param player_index integer Player index.
---@return table # Player GUI state table.
function utils.get_gui_state(player_index)
  storage.gui_state = storage.gui_state or {}
  local st = storage.gui_state[player_index]
  local default_stks = utils.get_default_stacks(player_index)
  local default_cnt = utils.get_default_count(player_index)

  if not st then
    st = {
      edit_items_text = default_cnt,
      edit_stacks_text = default_stks,
      new_mask_signal = { type = "virtual", name = "signal-A" },
      new_mask_val = utils.get_default_network_flag(),
      selected_section = nil,
      selected_slot = nil,
    }
    storage.gui_state[player_index] = st
  end
  return st
end

---Formats an input text string with appropriate sign.
---@param text_val? string|number Input text string or number.
---@param sign integer 1 or -1 multiplier.
---@return string # Formatted text string with sign.
function utils.format_input_text(text_val, sign)
  if text_val == nil or text_val == "" then return "" end
  local str_val = tostring(text_val)
  if str_val == "-" then return "-" end
  local num = tonumber(str_val)
  if not num then return str_val end

  if sign == -1 then
    if num == 0 then return str_val end
    return "-" .. tostring(math.abs(num))
  else
    return str_val
  end
end

---Computes final numeric count for a signal based on input items/stacks and sign setting.
---@param items_text? string|number Items count input text.
---@param stacks_text? string|number Stacks input text.
---@param signal? SignalID Target signal.
---@param sign integer 1 or -1 sign multiplier.
---@param is_stacks_edited boolean True if stacks input was edited.
---@param default_stacks? string Fallback default stacks setting.
---@return integer # Computed final 32-bit integer count.
function utils.compute_final_count(items_text, stacks_text, signal, sign, is_stacks_edited, default_stacks)
  local is_stackable = utils.is_stackable_signal(signal)
  local s_size = utils.get_stack_size(signal)

  local raw_count = 1
  if not is_stackable then
    raw_count = tonumber(items_text) or 1
  else
    local stacks_val = tonumber(stacks_text)
    if (not stacks_val or stacks_val == 0) and default_stacks and default_stacks ~= "" then
      stacks_val = tonumber(default_stacks)
    end

    if is_stacks_edited and stacks_val and stacks_val ~= 0 then
      raw_count = stacks_val * s_size
    elseif tonumber(items_text) and tonumber(items_text) ~= 0 then
      raw_count = tonumber(items_text)
    elseif stacks_val and stacks_val ~= 0 then
      raw_count = stacks_val * s_size
    else
      raw_count = s_size
    end
  end

  if sign == -1 then
    return utils.to_int32(-math.abs(raw_count))
  else
    return utils.to_int32(raw_count)
  end
end

---Recursively finds and focuses a named input textfield in the open Factorio GUI window.
---@param player_index integer|LuaPlayer Player index or player instance.
---@param field_name string The name property of the element to focus.
function utils.focus_input_field(player_index, field_name)
  if not player_index then return end
  local player = type(player_index) == "number" and game.get_player(player_index) or player_index
  if not player or not player.valid then return end

  local root = player.opened
  if not root then return end

  local function find_elem(elt)
    if not elt or not elt.valid then return nil end
    if elt.name == field_name then return elt end
    local children = elt.children
    if children then
      for _, ch in ipairs(children) do
        local found = find_elem(ch)
        if found then return found end
      end
    end
    return nil
  end

  local tf = find_elem(root)
  if tf then
    tf.focus()
  end
end

---Recursively finds a named scroll-pane in the open GUI and scrolls it to the bottom.
---@param player_index integer|LuaPlayer Player index or player instance.
---@param pane_name string The name property of the scroll-pane element.
function utils.scroll_pane_to_bottom(player_index, pane_name)
  if not player_index then return end
  local player = type(player_index) == "number" and game.get_player(player_index) or player_index
  if not player or not player.valid then return end

  local root = player.opened
  if not root then return end

  local function find_elem(elt)
    if not elt or not elt.valid then return nil end
    if elt.name == pane_name then return elt end
    local children = elt.children
    if children then
      for _, ch in ipairs(children) do
        local found = find_elem(ch)
        if found then return found end
      end
    end
    return nil
  end

  local pane = find_elem(root)
  if pane and pane.valid then
    pane.scroll_to_bottom()
  end
end

return utils
