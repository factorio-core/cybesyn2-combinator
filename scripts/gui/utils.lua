local constants = require "scripts.constants"
local C2CC = require "scripts.models.combinator"

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
          local comb = C2CC:New(entity)
          local netSig = comb:GetNetworkSignal()
          if netSig and netSig.Signal and netSig.Signal.name then
            local key = (netSig.Signal.type or "item") .. "_" .. netSig.Signal.name .. "_" .. tostring(netSig.Count)
            result[key] = { Signal = netSig.Signal, Count = netSig.Count }
          end
        end
      end
    end
  end

  return result
end

---Scans all active combinators and ghosts in the world and returns a sorted list of unique group names.
---@return string[] # Sorted array of unique group name strings.
function utils.get_all_global_groups()
  local group_map = {}

  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered { name = constants.ENTITY_NAME }
    local ghosts = surface.find_entities_filtered { name = "entity-ghost", ghost_name = constants.ENTITY_NAME }

    for _, entity_list in ipairs({ entities, ghosts }) do
      for _, entity in ipairs(entity_list) do
        if entity and entity.valid then
          local comb = C2CC:New(entity)
          local groups = comb:GetGroups()
          for _, g in ipairs(groups) do
            if g.RawGroupName and g.RawGroupName ~= "" and not group_map[g.RawGroupName] then
              group_map[g.RawGroupName] = g.Slots
            end
          end
        end
      end
    end
  end

  return group_map
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

---Initializes default settings for a player in storage if not already present.


---Updates station priority on Cybersyn 2 Constant Combinators matching old priority.
---@param old_priority integer Only combinators matching this old priority will be updated.
---@param new_priority integer The new station priority value.
---@return integer # Total count of updated combinators.
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

---Updates default network signal and mask on Cybersyn 2 Constant Combinators matching old network settings.
---@param old_network_signal? SignalID Only combinators matching this old signal will be updated.
---@param old_network_flag integer|string Only combinators matching this old bitmask flag will be updated.
---@param new_network_signal SignalID The new network mask signal.
---@param new_network_flag integer|string The new network bitmask value.
---@return integer # Total count of updated combinators.
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

---Recursively finds and focuses a named input textfield in the open Factorio GUI window.
---@param player_index integer|LuaPlayer Player index or player instance.
---@param field_name string The name property of the element to focus.
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
---@param player_index integer|LuaPlayer Player index or player instance.
---@param pane_name string The name property of the scroll-pane element.
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
