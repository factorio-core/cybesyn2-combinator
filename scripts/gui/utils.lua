local C2CC = require "scripts.models.combinator"
local constants = require "scripts.constants"

---@class C2CC.GuiUtils
local utils = {}

---Checks if an entity is a Cybersyn 2 Constant Combinator or its ghost.
---@param entity? LuaEntity
---@return boolean
function utils.is_combinator_entity(entity)
  if not entity or not entity.valid then return false end
  if entity.name == constants.ENTITY_NAME then return true end
  if entity.name == "entity-ghost" and entity.ghost_name == constants.ENTITY_NAME then return true end
  return false
end

---Converts any numeric value to a signed 32-bit integer (shared from combinator model).
---@param val any Number or string representation to convert.
---@return integer
function utils.to_int32(val)
  return C2CC.ToInt32(val)
end

---Formats a number into a short string representation with unit suffixes (e.g., 1.5k, 2M, 10G).
---@param n? number|string The number or numeric string to format.
---@return string
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

---Checks whether a signal is stackable (items only, not fluids or virtual signals).
---@param signal? SignalID
---@return boolean
function utils.is_stackable_signal(signal)
  if not signal or not signal.name then return false end
  if signal.type == "fluid" or signal.type == "virtual" or signal.type == "quality" then
    return false
  end
  return true
end

---Gets the item stack size for a given signal.
---@param signal? SignalID
---@return integer
function utils.get_stack_size(signal)
  if not signal or not signal.name then return 1 end
  if not utils.is_stackable_signal(signal) then return 1 end
  local proto = prototypes.item[signal.name]
  return proto and proto.stack_size or 1
end

---Updates station priority on all Cybersyn 2 Constant Combinators matching old priority.
---@param old_priority integer
---@param new_priority integer
---@return integer
function utils.apply_priority_to_all_combinators(old_priority, new_priority)
  if not game then return 0 end
  local oldPrio = tonumber(old_priority) or 0
  local newPrio = tonumber(new_priority) or 0
  local count = 0
  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local combinators = surface.find_entities_filtered({ name = constants.ENTITY_NAME })
      for _, entity in ipairs(combinators) do
        if entity and entity.valid then
          local comb = C2CC:New(entity)
          if comb:GetPriority() == oldPrio then
            comb:SetPriority(newPrio)
            count = count + 1
          end
        end
      end
    end
  end
  return count
end

---Updates default network signal and mask on all Cybersyn 2 Constant Combinators matching old network settings.
---@param old_network_signal? SignalID
---@param old_network_flag integer|string
---@param new_network_signal SignalID
---@param new_network_flag integer|string
---@return integer
function utils.apply_network_to_all_combinators(old_network_signal, old_network_flag, new_network_signal, new_network_flag)
  if not game then return 0 end
  local oldFlag = tonumber(old_network_flag) or 0
  local newFlag = tonumber(new_network_flag) or 0
  local count = 0

  for _, surface in pairs(game.surfaces) do
    if surface and surface.valid then
      local combinators = surface.find_entities_filtered({ name = constants.ENTITY_NAME })
      for _, entity in ipairs(combinators) do
        if entity and entity.valid then
          local comb = C2CC:New(entity)
          local current_net = comb:GetNetworkSignal()
          local matches_old = false
          if current_net and current_net.Signal and old_network_signal and old_network_signal.name then
            local same_type = (current_net.Signal.type or "item") == (old_network_signal.type or "item")
            if same_type and current_net.Signal.name == old_network_signal.name and tonumber(current_net.Count) == oldFlag then
              matches_old = true
            end
          elseif current_net == nil and (oldFlag == 0 or old_network_signal == nil) then
            matches_old = true
          end
          if matches_old then
            if new_network_signal and new_network_signal.name and newFlag ~= 0 then
              comb:SetNetworkSignal({ Signal = new_network_signal, Count = newFlag })
            else
              comb:SetNetworkSignal(nil)
            end
            count = count + 1
          end
        end
      end
    end
  end
  return count
end

---Returns all logistic group names via the vanilla Factorio 2.0 API.
---Same source as the vanilla constant combinator group dropdown.
---@return table<string, true>  Set of group names.
function utils.get_all_global_groups()
  local group_map = {}
  if not game then return group_map end

  for _, force in pairs(game.forces) do
    local ok, groups = pcall(force.get_logistic_groups)
    if ok and groups then
      for _, group_name in ipairs(groups) do
        if group_name ~= "" then
          group_map[group_name] = true
        end
      end
    end
  end

  return group_map
end

---Recursively finds and focuses a named input textfield in the open Factorio GUI window.
---@param player_index integer|LuaPlayer
---@param field_name string
function utils.focus_input_field(player_index, field_name)
  if not player_index or not game then return end
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
---@param player_index integer|LuaPlayer
---@param pane_name string
function utils.scroll_pane_to_bottom(player_index, pane_name)
  if not player_index or not game then return end
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
