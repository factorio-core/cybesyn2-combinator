local priorities = require "scripts.gui.priorities"
local sig_lib = require("__cybersyn2-combinator__/lib/core/signal")

local networks = {}

function networks.are_networks_equal(old_list, new_list)
  if old_list == new_list then return true end
  if not old_list or not new_list then return false end
  if #old_list ~= #new_list then return false end
  for i = 1, #new_list do
    local a = old_list[i]
    local b = new_list[i]
    if not a or not b or not a.Signal or not b.Signal then return false end
    if a.Signal.name ~= b.Signal.name or a.Signal.type ~= b.Signal.type or a.Signal.quality ~= b.Signal.quality or a.Count ~= b.Count then
      return false
    end
  end
  return true
end

function networks.get_all_global_active_networks()
  if not game or not remote.interfaces["cybersyn2"] then return {} end

  local unique_map = {}

  local process_networks_dict = function(dict)
    if not dict or type(dict) ~= "table" then return end
    for k, count in pairs(dict) do
      local parsed = priorities.parse_signal_key(k)
      if not parsed then
        local stype = sig_lib.get_signal_type_from_name(k)
        if stype then parsed = { type = stype, name = k } end
      end
      if parsed and parsed.name then
        local c = tonumber(count) or 0
        local key = (parsed.type or "item") .. "_" .. parsed.name .. "_" .. (parsed.quality or "normal") .. "_" .. tostring(c)
        if not unique_map[key] then
          unique_map[key] = { Signal = parsed, Count = c }
        end
      end
    end
  end

  local process_networks_on_object = function(obj)
    local net = obj.networks
    if not net or type(net) ~= "table" or not next(net) then
      net = obj.network or obj.network_mask or obj.network_flag or obj.network_id
    end
    process_networks_dict(net)
  end

  local stops_res = remote.call("cybersyn2", "query", { type = "stops", all = true })
  if not stops_res or not stops_res.data then return {} end

  local inv_ids = {}
  for _, stop in ipairs(stops_res.data) do
    process_networks_on_object(stop)
    if stop.inventory_id then table.insert(inv_ids, stop.inventory_id) end
    if stop.shared_inventory_master then table.insert(inv_ids, stop.shared_inventory_master) end
  end

  if #inv_ids > 0 then
    local inv_res = remote.call("cybersyn2", "query", { type = "inventories", ids = inv_ids })
    if inv_res and inv_res.data then
      for _, inv in ipairs(inv_res.data) do
        if inv.orders then
          for _, order_obj in ipairs(inv.orders) do
            process_networks_on_object(order_obj)
          end
        end
      end
    end
  end

  local result = {}
  for _, entry in pairs(unique_map) do
    table.insert(result, entry)
  end
  table.sort(result, function(a, b)
    local na = a.Signal.name or ""
    local nb = b.Signal.name or ""
    if na ~= nb then return na < nb end
    return (a.Count or 0) < (b.Count or 0)
  end)
  return result
end

return networks
