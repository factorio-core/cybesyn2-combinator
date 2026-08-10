local C2CC = require "scripts.models.combinator"

local priorities = {}

---Parses a Cybersyn 2 signal key string into a SignalID by searching fluid and item prototypes.
function priorities.parse_signal_key(key)
  if not key or type(key) ~= "string" or key == "" then return nil end

  local sig_name = key
  local sig_quality = nil

  -- Clean prefix if present
  if sig_name:sub(1, 6) == "fluid/" then
    sig_name = sig_name:sub(7)
  elseif sig_name:sub(1, 5) == "item/" then
    sig_name = sig_name:sub(6)
  elseif sig_name:sub(1, 8) == "virtual/" then
    sig_name = sig_name:sub(9)
  end

  -- Extract quality if present (e.g. "item-name|rare")
  if sig_name:find("|") then
    local parts = {}
    for part in sig_name:gmatch("[^|]+") do
      table.insert(parts, part)
    end
    sig_name = parts[1]
    if parts[2] and parts[2] ~= "normal" then
      sig_quality = parts[2]
    end
  end

  local p_fluid = prototypes and prototypes.fluid
  local p_item = prototypes and prototypes.item

  local sig_type = nil
  if p_fluid and p_fluid[sig_name] then
    sig_type = "fluid"
  elseif p_item and p_item[sig_name] then
    sig_type = "item"
  else
    return nil
  end

  return {
    type = sig_type,
    name = sig_name,
    quality = sig_quality
  }
end

---Compares two priority lists strictly by unique signal identity (type, name, quality).
---@param old_list table|nil
---@param new_list table|nil
---@return boolean # True if both lists contain identical unique signals
function priorities.are_priorities_equal(old_list, new_list)
  if old_list == new_list then return true end
  if not old_list or not new_list then return false end
  if #old_list ~= #new_list then return false end

  for i = 1, #new_list do
    local a = old_list[i]
    local b = new_list[i]
    if not a or not b or not a.signal or not b.signal then return false end
    if a.signal.name ~= b.signal.name or a.signal.type ~= b.signal.type or a.signal.quality ~= b.signal.quality then
      return false
    end
  end

  return true
end

---Finds the single Cybersyn 2 station associated with this C2CC combinator,
---and queries Cybersyn 2 API to retrieve its inventory IDs.
---@param entity LuaEntity
---@return integer|nil target_stop_unit
---@return integer[] target_inv_ids
function priorities.find_station_for_combinator(entity)
  if not entity or not entity.valid or not remote.interfaces["cybersyn2"] then
    return nil, {}
  end

  local pos = entity.position
  local search_area = {
    { pos.x - 3.5, pos.y - 3.5 },
    { pos.x + 3.5, pos.y + 3.5 }
  }

  -- 1. Find nearby train-stop entity
  local nearby_stops = entity.surface.find_entities_filtered({
    area = search_area,
    type = "train-stop"
  })

  local stop_unit = nearby_stops[1] and nearby_stops[1].unit_number or nil

  -- 2. If no direct train-stop, check straight-rails
  if not stop_unit then
    local nearby_rails = entity.surface.find_entities_filtered({
      area = search_area,
      type = "straight-rail"
    })
    if #nearby_rails > 0 then
      local stops_all = remote.call("cybersyn2", "query", { type = "stops", all = true })
      if stops_all and stops_all.data then
        for _, s in ipairs(stops_all.data) do
          local s_ent = s.entity
          if s_ent and s_ent.valid and s_ent.surface.index == entity.surface.index then
            local dx = s_ent.position.x - entity.position.x
            local dy = s_ent.position.y - entity.position.y
            if (dx * dx + dy * dy) <= 100 then
              stop_unit = s.entity_id or s_ent.unit_number
              break
            end
          end
        end
      end
    end
  end

  if not stop_unit then
    return nil, {}
  end

  -- 3. Query Cybersyn 2 API for this specific station by unit_number
  local stop_res = remote.call("cybersyn2", "query", { type = "stops", unit_numbers = { stop_unit } })
  local stop_obj = stop_res and stop_res.data and stop_res.data[1]

  local target_inv_ids = {}
  local inv_map = {}

  if stop_obj then
    if stop_obj.inventory_id and not inv_map[stop_obj.inventory_id] then
      inv_map[stop_obj.inventory_id] = true
      table.insert(target_inv_ids, stop_obj.inventory_id)
    end

    if stop_obj.shared_inventory_master and not inv_map[stop_obj.shared_inventory_master] then
      inv_map[stop_obj.shared_inventory_master] = true
      table.insert(target_inv_ids, stop_obj.shared_inventory_master)
    end
  end

  return stop_unit, target_inv_ids
end

---Queries Cybersyn 2 for priorities and demand/supply info of unique signals in station inventories near the combinator.
---@param entity LuaEntity Combinator entity.
---@param cached_inv_ids integer[]|nil Optional cached array of station inventory IDs.
---@return table # Array of signal priority stats
function priorities.query_signal_priorities(entity, cached_inv_ids)
  if not entity or not entity.valid or not remote.interfaces["cybersyn2"] then
    return {}
  end

  local comb = C2CC:New(entity)
  local unique_signals_map = {}
  local unique_signals_list = {}

  -- STEP 1: Helper function to register unique signals
  local add_signals_from_dict = function(dict)
    if not dict or type(dict) ~= "table" then return end
    for k in pairs(dict) do
      local parsed = priorities.parse_signal_key(k)
      if parsed and parsed.name and not unique_signals_map[parsed.name] then
        unique_signals_map[parsed.name] = parsed
        table.insert(unique_signals_list, parsed)
      end
    end
  end

  -- STEP 2: Retrieve network mask of the current combinator
  local current_net_sig = comb:GetNetworkSignal()
  local current_net_count = current_net_sig and current_net_sig.Count or nil
  local current_net_name = (current_net_sig and current_net_sig.Signal) and current_net_sig.Signal.name or nil

  -- Helper function to check if order network matches combinator network
  local is_network_matched = function(order_obj, inv)
    if not current_net_sig or not current_net_sig.Signal then
      return true -- Match all networks if no network mask signal is set
    end

    local target_net = order_obj.network or order_obj.network_mask or order_obj.network_id or order_obj.network_flag or
        (inv and (inv.network or inv.network_mask or inv.network_id or inv.network_flag))

    if not target_net then return true end

    if type(target_net) == "number" and type(current_net_count) == "number" and current_net_count ~= 0 then
      return bit32.band(target_net, current_net_count) ~= 0
    elseif type(target_net) == "string" and current_net_name then
      return target_net == current_net_name or target_net:find(current_net_name, 1, true) ~= nil
    end

    return true
  end

  -- STEP 3: Locate target Cybersyn 2 station inventories
  local target_inv_ids = cached_inv_ids
  if not target_inv_ids or #target_inv_ids == 0 then
    local _, resolved_inv_ids = priorities.find_station_for_combinator(entity)
    target_inv_ids = resolved_inv_ids
  end

  -- Query target station inventories and extract unique items/fluids
  if target_inv_ids and #target_inv_ids > 0 then
    local inv_res = remote.call("cybersyn2", "query", { type = "inventories", ids = target_inv_ids })
    if inv_res and inv_res.data then
      for _, inv in ipairs(inv_res.data) do
        add_signals_from_dict(inv.inventory)
        add_signals_from_dict(inv.inflow)
        add_signals_from_dict(inv.outflow)

        if inv.orders then
          for _, order_obj in ipairs(inv.orders) do
            add_signals_from_dict(order_obj.provides)
            add_signals_from_dict(order_obj.requests)
            add_signals_from_dict(order_obj.requested_fluids)
          end
        end
      end
    end
  end

  -- Return empty result if no signals found
  if #unique_signals_list == 0 then
    return {}
  end

  -- STEP 4: Initialize structured priority stats container for each signal
  local signal_stats = {}
  for _, sig in ipairs(unique_signals_list) do
    signal_stats[sig.name] = {
      signal = sig,
      req_min = nil,
      req_max = nil,
      req_found = false,
      sup_min = nil,
      sup_max = nil,
      sup_found = false,
    }
  end

  -- STEP 5: Query all Cybersyn 2 orders and calculate Min/Max priorities for Request and Supply
  local stops_res = remote.call("cybersyn2", "query", { type = "stops", all = true })
  if stops_res and stops_res.data then
    local inv_ids = {}
    for _, stop in ipairs(stops_res.data) do
      if stop.inventory_id then
        table.insert(inv_ids, stop.inventory_id)
      end
      if stop.shared_inventory_master then
        table.insert(inv_ids, stop.shared_inventory_master)
      end
    end

    if #inv_ids > 0 then
      local inv_res = remote.call("cybersyn2", "query", { type = "inventories", ids = inv_ids })
      if inv_res and inv_res.data then
        local process_order_dict = function(dict, is_request, prio)
          if not dict or type(dict) ~= "table" then return end
          for k in pairs(dict) do
            local parsed = priorities.parse_signal_key(k)
            if parsed and parsed.name and signal_stats[parsed.name] then
              local stat = signal_stats[parsed.name]
              if is_request then
                stat.req_found = true
                if not stat.req_max or prio > stat.req_max then stat.req_max = prio end
                if not stat.req_min or prio < stat.req_min then stat.req_min = prio end
              else
                stat.sup_found = true
                if not stat.sup_max or prio > stat.sup_max then stat.sup_max = prio end
                if not stat.sup_min or prio < stat.sup_min then stat.sup_min = prio end
              end
            end
          end
        end

        for _, inv in ipairs(inv_res.data) do
          if inv.orders then
            for _, order_obj in ipairs(inv.orders) do
              if is_network_matched(order_obj, inv) then
                local prio = order_obj.priority or 0
                process_order_dict(order_obj.requests, true, prio)
                process_order_dict(order_obj.requested_fluids, true, prio)
                process_order_dict(order_obj.provides, false, prio)
              end
            end
          end
        end
      end
    end
  end

  -- STEP 6: Build final array of priority statistics for GUI rendering
  local result_list = {}
  for _, sig in ipairs(unique_signals_list) do
    local stat = signal_stats[sig.name]
    table.insert(result_list, {
      signal = sig,
      req_min = stat and stat.req_min or nil,
      req_max = stat and stat.req_max or nil,
      req_found = stat and stat.req_found or false,
      sup_min = stat and stat.sup_min or nil,
      sup_max = stat and stat.sup_max or nil,
      sup_found = stat and stat.sup_found or false,
    })
  end

  return result_list
end

return priorities
