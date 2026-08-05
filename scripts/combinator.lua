local constants = require "scripts.constants"

---@class C2CC.NetworkSignalData
---@field public index integer Network slot index.
---@field public signal SignalID Network virtual signal prototype.
---@field public count integer Network bitmask count value.

---@class C2CC
---@field public entity LuaEntity Factorio combinator entity instance.
---@field public is_ghost boolean True if entity is entity-ghost.
local C2CC = {}
C2CC.__index = C2CC

-- Internal section IDs for reserved system sections
local CYBERSYN_SECTION_ID = 2
local NETWORK_SECTION_ID = 3

---Clamps numeric value to signed 32-bit integer.
---@param val any Input value.
---@return integer # 32-bit integer.
local function to_int32(val)
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

--------------------------------------------------------------------------------
-- Constructor & Validation
--------------------------------------------------------------------------------

---Creates a new C2CC wrapper instance.
---@param entity LuaEntity The Factorio combinator entity.
---@param is_ghost? boolean Optional flag if entity is a ghost.
---@return C2CC # Wrapper object instance.
function C2CC:new(entity, is_ghost)
  local obj = setmetatable({}, C2CC)
  obj.entity = entity
  obj.is_ghost = (is_ghost == true) or (entity and entity.valid and entity.name == "entity-ghost")
  return obj
end

---Checks if the underlying Factorio entity is valid.
---@return boolean # True if entity is valid.
function C2CC:is_valid_entity()
  return self.entity and self.entity.valid
end

---Gets the control behavior object of the combinator entity.
---@return LuaConstantCombinatorControlBehavior? # Control behavior instance, or nil.
function C2CC:get_control_behavior()
  if not self:is_valid_entity() then return nil end
  if self.entity.get_control_behavior then
    local cb = self.entity.get_control_behavior()
    if cb then return cb end
  end
  if self.is_ghost then
    return self.entity.tags and self.entity.tags.control_behavior or nil
  end
  return nil
end

--------------------------------------------------------------------------------
-- Output Status (Enable / Disable)
--------------------------------------------------------------------------------

---Checks if the combinator output behavior is enabled.
---@return boolean # True if combinator output is enabled.
function C2CC:is_enabled()
  if not self:is_valid_entity() then return false end
  local cb = self:get_control_behavior()
  if not cb then return false end
  return cb.enabled ~= false
end

---Sets the active working output state of the combinator.
---@param enabled boolean New enabled status.
function C2CC:set_enabled(enabled)
  if not self:is_valid_entity() then return end
  local cb = self:get_control_behavior()
  if not cb then return end
  cb.enabled = enabled
end

--------------------------------------------------------------------------------
-- Reserved System Section Management
--------------------------------------------------------------------------------

---Scans sections for an existing system section matching a predicate.
---@param cb LuaConstantCombinatorControlBehavior Control behavior.
---@param exclude_sec? LuaLogisticSection Reserved section to exclude from check.
---@param predicate fun(signal: SignalID): boolean Predicate function.
---Scans sections for an existing system section matching a predicate.
---@param cb LuaConstantCombinatorControlBehavior Control behavior.
---@param predicate fun(signal: SignalID): boolean Predicate function.
---@return LuaLogisticSection? # Found section or nil.
local function find_section_by_predicate(cb, predicate)
  local empty_sec = nil
  for _, section in ipairs(cb.sections) do
    if section and section.valid then
      local filters_count = section.filters_count or 0
      local has_filters = false
      for i = 1, math.max(1, filters_count) do
        local filter = section.get_slot(i)
        if filter and filter.value and filter.value.name then
          has_filters = true
          if predicate(filter.value) then
            return section
          end
        end
      end
      if not has_filters and not empty_sec then
        empty_sec = section
      end
    end
  end
  return empty_sec
end

---Gets or creates a reserved system section (Cybersyn priority section or Network section).
---@param id integer System section ID (CYBERSYN_SECTION_ID or NETWORK_SECTION_ID).
---@return LuaLogisticSection? # Logistic section instance.
function C2CC:get_or_create_section(id)
  if not self:is_valid_entity() then return nil end
  local cb = self:get_control_behavior()
  if not cb then return nil end

  local section = nil
  if id == CYBERSYN_SECTION_ID then
    section = find_section_by_predicate(cb, function(signal)
      return signal.type == "virtual" and signal.name == constants.SETTINGS.CS_PRIORITY_NAME
    end)
  elseif id == NETWORK_SECTION_ID then
    section = find_section_by_predicate(cb, function(signal)
      return signal.type == "virtual" and signal.name ~= constants.SETTINGS.CS_PRIORITY_NAME
    end)
  end

  if not section or not section.valid then
    section = cb.add_section()
  end
  return section
end

---Constructs a Factorio logistic filter object.
---@param signal? SignalID Signal prototype.
---@param count integer Signal count value.
---@return LogisticFilter? # Created filter table, or nil if signal is invalid.
local function make_filter(signal, count)
  if not signal or not signal.name then return nil end
  local min_val = to_int32(count)
  local filter = {
    value = {
      type = signal.type or "item",
      name = signal.name,
      quality = signal.quality or "normal"
    },
    min = min_val
  }
  if signal.comparator then filter.comparator = signal.comparator end
  return filter
end

--------------------------------------------------------------------------------
-- Section Groups Management
--------------------------------------------------------------------------------

---@class C2CC.SectionGroupData
---@field public section_index integer Group section index in control behavior.
---@field public group_name string Formatted display group name.
---@field public raw_group_name string Raw unformatted group name string.
---@field public is_active boolean Whether section is enabled/active.
---@field public max_slot_found integer Highest non-empty slot index.
---@field public slots table<integer, { signal: SignalID, count: integer }> Slot filters data map.

---Returns structured Groups list mapping slots to their exact 1-indexed position.
---@return C2CC.SectionGroupData[] # Array of structured group data tables.
function C2CC:get_groups()
  local cb = self:get_control_behavior()
  if not cb then return {} end

  local cs_sec = self:get_or_create_section(CYBERSYN_SECTION_ID)
  local net_sec = self:get_or_create_section(NETWORK_SECTION_ID)

  local groups = {}

  for _, section in pairs(cb.sections) do
    if section and section.valid and section ~= cs_sec and section ~= net_sec then
      local raw_name = section.group or ""
      local disp_name = (raw_name ~= "") and raw_name or "[no group assigned]"

      local slot_map = {}
      local max_slot_found = 0
      local filters_count = section.filters_count or 0

      for i = 1, math.max(40, filters_count) do
        local filter = section.get_slot(i)
        if filter and filter.value and filter.value.name then
          slot_map[i] = {
            signal = filter.value,
            count = filter.min or 0
          }
          if i > max_slot_found then
            max_slot_found = i
          end
        end
      end

      table.insert(groups, {
        section_index = section.index,
        raw_group_name = raw_name,
        group_name = disp_name,
        slots = slot_map,
        max_slot_found = max_slot_found,
        is_active = section.active ~= false
      })
    end
  end

  return groups
end

---Adds a new group section.
---@param group_name? string Optional section group name.
---@return LuaLogisticSection? # Created logistic section.
function C2CC:add_group(group_name)
  local cb = self:get_control_behavior()
  if not cb then return end
  return cb.add_section(group_name or "")
end

---Renames a group section.
---@param section_index integer Section index in control behavior.
---@param group_name? string New group name string.
function C2CC:rename_group(section_index, group_name)
  local cb = self:get_control_behavior()
  if not cb then return end
  local section = cb.get_section(section_index)
  if not section or not section.valid then return end
  section.group = group_name or ""
end

---Removes a group section by index.
---@param section_index integer Section index in control behavior.
function C2CC:remove_group(section_index)
  local cb = self:get_control_behavior()
  if not cb then return end
  cb.remove_section(section_index)
end

---Sets a signal filter in a specific group section slot.
---@param section_index integer Section index.
---@param slot_index integer Slot index within section.
---@param signal? SignalID Signal prototype.
---@param count integer Signal count value.
function C2CC:set_group_slot(section_index, slot_index, signal, count)
  local cb = self:get_control_behavior()
  if not cb then return end
  local section = cb.get_section(section_index)
  if not section or not section.valid then return end

  local filter = make_filter(signal, count)
  if filter then
    section.set_slot(slot_index, filter)
  else
    section.clear_slot(slot_index)
  end
end

---Clears a signal filter from a group section slot.
---@param section_index integer Section index.
---@param slot_index integer Slot index.
function C2CC:remove_group_slot(section_index, slot_index)
  local cb = self:get_control_behavior()
  if not cb then return end
  local section = cb.get_section(section_index)
  if not section or not section.valid then return end
  section.clear_slot(slot_index)
end

--------------------------------------------------------------------------------
-- Priority & Network Signals API
--------------------------------------------------------------------------------

---Gets the Cybersyn station priority value.
---@return integer # Station priority integer.
function C2CC:get_priority()
  local section = self:get_or_create_section(CYBERSYN_SECTION_ID)
  if not section then return 0 end
  local filter = section.get_slot(1)
  if filter and filter.value and filter.value.name == constants.SETTINGS.CS_PRIORITY_NAME then
    return filter.min or 0
  end
  return 0
end

---Sets the Cybersyn station priority value.
---@param value integer Station priority integer.
function C2CC:set_priority(value)
  local section = self:get_or_create_section(CYBERSYN_SECTION_ID)
  if not section then return end
  if value and value ~= 0 then
    section.set_slot(1, make_filter({ type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME }, value))
  else
    section.clear_slot(1)
  end
end

---Gets all network mask virtual signals.
---@return C2CC.NetworkSignalData[] # List of active network mask signal data objects.
function C2CC:get_network_signals()
  local section = self:get_or_create_section(NETWORK_SECTION_ID)
  if not section then return {} end
  local results = {}
  local filters_count = section.filters_count or 10
  for i = 1, math.max(10, filters_count) do
    local filter = section.get_slot(i)
    if filter and filter.value and filter.value.name then
      table.insert(results, {
        index = i,
        signal = filter.value,
        count = filter.min or 0
      })
    end
  end
  return results
end

---Sets the array of network mask virtual signals.
---@param signals { signal: SignalID, count: integer }[] Array of network signal data objects.
function C2CC:set_network_signals(signals)
  local section = self:get_or_create_section(NETWORK_SECTION_ID)
  if not section then return end
  local max_c = math.max(10, section.filters_count or 10)
  for i = 1, max_c do
    section.clear_slot(i)
  end
  for i, sig in ipairs(signals) do
    local filter = make_filter(sig.signal, sig.count)
    if filter then
      section.set_slot(i, filter)
    end
  end
end

---Sorts signals alphabetically within item section groups.
function C2CC:sort_signals()
  local cb = self:get_control_behavior()
  if not cb then return end
  local cs_sec = self:get_or_create_section(CYBERSYN_SECTION_ID)
  local net_sec = self:get_or_create_section(NETWORK_SECTION_ID)

  for _, section in pairs(cb.sections) do
    if section and section.valid and section ~= cs_sec and section ~= net_sec then
      local active = {}
      for i = 1, section.filters_count or 40 do
        local slot = section.get_slot(i)
        if slot and slot.value and slot.value.name then
          table.insert(active, slot)
        end
        section.clear_slot(i)
      end
      table.sort(active, function(a, b)
        return (a.value.name or "") < (b.value.name or "")
      end)
      for i, slot in ipairs(active) do
        section.set_slot(i, slot)
      end
    end
  end
end

---Copies all settings, priorities, network signals, and section groups from another combinator instance.
---@param src_comb C2CC Source combinator instance.
function C2CC:copy_from(src_comb)
  if not src_comb then return end
  local dest_cb = self:get_control_behavior()
  local src_cb = src_comb:get_control_behavior()
  if not dest_cb or not src_cb then return end

  -- Copy Priority
  self:set_priority(src_comb:get_priority())

  -- Copy Network Signals
  self:set_network_signals(src_comb:get_network_signals())

  -- Clear existing non-system section groups in destination
  local dest_cs_sec = self:get_or_create_section(CYBERSYN_SECTION_ID)
  local dest_net_sec = self:get_or_create_section(NETWORK_SECTION_ID)

  for _, section in pairs(dest_cb.sections) do
    if section and section.valid and section ~= dest_cs_sec and section ~= dest_net_sec then
      dest_cb.remove_section(section.index)
    end
  end

  -- Copy groups from source
  local src_groups = src_comb:get_groups()
  for _, grp in ipairs(src_groups) do
    local new_sec = self:add_group(grp.raw_group_name)
    if new_sec and new_sec.valid then
      new_sec.active = grp.is_active
      for slot_idx, sdata in pairs(grp.slots) do
        if sdata and sdata.signal then
          self:set_group_slot(new_sec.index, slot_idx, sdata.signal, sdata.count)
        end
      end
    end
  end
end

return C2CC
