local constants = require "scripts.constants"
local PlayerSettings = require "scripts.models.player_settings"

---Converts any numeric value to a signed 32-bit integer.
---@param val any Number or string representation to convert.
---@return integer
local function ToInt32(val)
  local n = tonumber(val) or 0
  if n > 2147483647 then
    if n <= 4294967295 then
      return math.floor(n - 4294967296)
    else
      return 2147483647
    end
  elseif n < -2147483648 then
    return -2147483648
  end
  return math.floor(n)
end

---@class C2CC.NetworkSignal
---@field Signal SignalID
---@field Count integer

---@class C2CC.SectionGroupData
---@field public GroupIndex integer Section group index in control behavior.
---@field public GroupName string Formatted display group name.
---@field public RawGroupName string Raw unformatted group name string.
---@field public IsActive boolean Whether section is enabled/active.
---@field public MaxSlotFound integer Highest non-empty slot index.
---@field public Slots table<integer, { Signal: SignalID, Count: integer }> Slot filters data map.

---@class C2CC
---@field public Entity LuaEntity The Factorio combinator entity instance.
local C2CC = {}
C2CC.__index = C2CC

---@param entity LuaEntity
---@return C2CC
function C2CC:New(entity)
  local obj = setmetatable({}, C2CC)
  if entity and entity.valid then
    obj.Entity = entity
  end
  return obj
end

---@return LuaEntity|nil
function C2CC:GetEntity()
  if self.Entity and self.Entity.valid then
    return self.Entity
  end
  return nil
end

---@return LuaConstantCombinatorControlBehavior|nil
function C2CC:GetControlBehavior()
  local entity = self:GetEntity()
  if entity and entity.get_control_behavior then
    return entity.get_control_behavior()
  end
  return nil
end

---Ensures section at specified index exists on control behavior.
---@param cb LuaConstantCombinatorControlBehavior
---@param sectionIndex integer
---@return LuaLogisticSection|nil
local function getOrCreateSection(cb, sectionIndex)
  if not cb or not cb.valid then return nil end
  while cb.sections_count < sectionIndex do
    cb.add_section("")
  end
  return cb.get_section(sectionIndex)
end

---@param signal SignalID|nil
---@param count integer|string
---@return LogisticFilter|nil
local function MakeFilter(signal, count)
  if not signal or not signal.name then return nil end
  local minVal = ToInt32(count)
  local filter = {
    value = {
      type = signal.type or "item",
      name = signal.name,
      quality = signal.quality or "normal"
    },
    min = minVal
  }
  if signal.comparator then filter.comparator = signal.comparator end
  return filter
end

---@return boolean
function C2CC:IsEnabled()
  local cb = self:GetControlBehavior()
  if not cb then return true end
  return cb.enabled
end

---@param enabled boolean
function C2CC:SetEnabled(enabled)
  local cb = self:GetControlBehavior()
  if cb then
    cb.enabled = enabled
  end
end

---@return integer
function C2CC:GetPriority()
  local cb = self:GetControlBehavior()
  if not cb then return 0 end
  local sec = getOrCreateSection(cb, constants.SECTIONS.CYBERSYN_PRIORITY)
  if not sec then return 0 end
  local filter = sec.get_slot(1)
  if filter and filter.value and filter.value.name == constants.SETTINGS.CS_PRIORITY_NAME then
    return filter.min or 0
  end
  return 0
end

---@param value number|string
function C2CC:SetPriority(value)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = getOrCreateSection(cb, constants.SECTIONS.CYBERSYN_PRIORITY)
  if not sec then return end
  local n = ToInt32(value)
  if n ~= 0 then
    sec.set_slot(1, MakeFilter({ type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME }, n))
  else
    sec.clear_slot(1)
  end
end

---@return C2CC.NetworkSignal|nil
function C2CC:GetNetworkSignal()
  local cb = self:GetControlBehavior()
  if not cb then return nil end
  local sec = getOrCreateSection(cb, constants.SECTIONS.NETWORK_MASK)
  if not sec then return nil end
  local filter = sec.get_slot(1)
  if filter and filter.value and filter.value.name then
    return { Signal = filter.value, Count = filter.min or 0 }
  end
  return nil
end

---@param signalData C2CC.NetworkSignal|nil
function C2CC:SetNetworkSignal(signalData)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = getOrCreateSection(cb, constants.SECTIONS.NETWORK_MASK)
  if not sec then return end
  if signalData and signalData.Signal and signalData.Signal.name then
    sec.set_slot(1, MakeFilter(signalData.Signal, signalData.Count))
  else
    sec.clear_slot(1)
  end
end

---@return C2CC.SectionGroupData[]
function C2CC:GetGroups()
  local cb = self:GetControlBehavior()
  if not cb then return {} end

  -- Ensure system sections (Section 1: Priority, Section 2: Network Mask) exist
  getOrCreateSection(cb, constants.SECTIONS.CYBERSYN_PRIORITY)
  getOrCreateSection(cb, constants.SECTIONS.NETWORK_MASK)

  local groups = {}
  for secIdx = 3, cb.sections_count do
    local sec = cb.get_section(secIdx)
    if sec and sec.valid then
      local rawName = sec.group or ""
      local displayName = (rawName ~= "") and rawName or "[no group assigned]"

      local slotMap = {}
      local maxSlotFound = 0
      local filtersCount = sec.filters_count or 0

      for i = 1, math.max(40, filtersCount) do
        local filter = sec.get_slot(i)
        if filter and filter.value and filter.value.name then
          slotMap[i] = {
            Signal = filter.value,
            Count = filter.min or 0
          }
          if i > maxSlotFound then
            maxSlotFound = i
          end
        end
      end

      table.insert(groups, {
        GroupIndex = sec.index,
        RawGroupName = rawName,
        GroupName = displayName,
        IsActive = sec.active ~= false,
        MaxSlotFound = maxSlotFound,
        Slots = slotMap
      })
    end
  end

  return groups
end

---@param groupIndex integer
---@param slotIndex integer
---@return SignalID|nil, integer
function C2CC:GetGroupSlot(groupIndex, slotIndex)
  local cb = self:GetControlBehavior()
  if not cb then return nil, 0 end
  local sec = cb.get_section(groupIndex)
  if not sec or not sec.valid then return nil, 0 end
  local filter = sec.get_slot(slotIndex)
  if filter and filter.value and filter.value.name then
    return filter.value, filter.min or 0
  end
  return nil, 0
end

---@param groupName string|nil
---@return LuaLogisticSection|nil
function C2CC:AddGroup(groupName)
  local cb = self:GetControlBehavior()
  if not cb then return nil end
  getOrCreateSection(cb, constants.SECTIONS.CYBERSYN_PRIORITY)
  getOrCreateSection(cb, constants.SECTIONS.NETWORK_MASK)
  return cb.add_section(groupName or "")
end

---@param groupIndex integer
---@param groupName string|nil
function C2CC:RenameGroup(groupIndex, groupName)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = cb.get_section(groupIndex)
  if sec and sec.valid then
    sec.group = groupName or ""
  end
end

---@param groupIndex integer
function C2CC:RemoveGroup(groupIndex)
  local cb = self:GetControlBehavior()
  if not cb then return end
  cb.remove_section(groupIndex)
end

---@param groupIndex integer
---@param isActive boolean
function C2CC:SetGroupActive(groupIndex, isActive)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = cb.get_section(groupIndex)
  if sec and sec.valid then
    sec.active = isActive ~= false
  end
end

---@param groupIndex integer
---@param slotIndex integer
---@param signal SignalID|nil
---@param count integer|string
function C2CC:SetGroupSlot(groupIndex, slotIndex, signal, count)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = cb.get_section(groupIndex)
  if not sec or not sec.valid then return end
  local filter = MakeFilter(signal, count)
  if filter then
    sec.set_slot(slotIndex, filter)
  else
    sec.clear_slot(slotIndex)
  end
end

---@param groupIndex integer
---@param slots table
function C2CC:SetGroupSlotsBulk(groupIndex, slots)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = cb.get_section(groupIndex)
  if not sec or not sec.valid then return end
  local filtersCount = sec.filters_count or 40
  for i = 1, math.max(40, filtersCount) do
    sec.clear_slot(i)
  end
  for k, v in pairs(slots or {}) do
    local sIdx = tonumber(k)
    if sIdx and v then
      local sig = v.Signal or v.signal
      local cnt = v.Count or v.count
      local filter = MakeFilter(sig, cnt)
      if filter then
        sec.set_slot(sIdx, filter)
      end
    end
  end
end

---@param groupIndex integer
---@param slotIndex integer
function C2CC:RemoveGroupSlot(groupIndex, slotIndex)
  local cb = self:GetControlBehavior()
  if not cb then return end
  local sec = cb.get_section(groupIndex)
  if sec and sec.valid then
    sec.clear_slot(slotIndex)
  end
end

---Copies settings, priority, network signal, and groups from another combinator instance.
---@param srcComb C2CC Source combinator instance.
function C2CC:CopyFrom(srcComb)
  if not srcComb then return end
  local destCb = self:GetControlBehavior()
  local srcCb = srcComb:GetControlBehavior()
  if not destCb or not srcCb then return end

  self:SetPriority(srcComb:GetPriority())
  self:SetNetworkSignal(srcComb:GetNetworkSignal())

  local destCsSec = getOrCreateSection(destCb, constants.SECTIONS.CYBERSYN_PRIORITY)
  local destNetSec = getOrCreateSection(destCb, constants.SECTIONS.NETWORK_MASK)

  for secIdx = destCb.sections_count, 3, -1 do
    destCb.remove_section(secIdx)
  end

  local srcGroups = srcComb:GetGroups()
  for _, grp in ipairs(srcGroups) do
    local newSec = self:AddGroup(grp.RawGroupName)
    if newSec and newSec.valid then
      newSec.active = grp.IsActive
      for slotIdx, sdata in pairs(grp.Slots) do
        if sdata and sdata.Signal then
          self:SetGroupSlot(newSec.index, slotIdx, sdata.Signal, sdata.Count)
        end
      end
    end
  end
end

---@param fromBlueprint boolean
---@param playerIndex? integer
function C2CC:InitializeDefaults(fromBlueprint, playerIndex)
  if fromBlueprint then return end
  local cb = self:GetControlBehavior()
  if not cb then return end

  local ps = PlayerSettings.Get(playerIndex or 1)

  local defaultPriority = tonumber(ps and ps.Priority) or constants.SETTINGS.DEFAULT_PRIORITY
  local defaultNetworkFlag = tonumber(ps and ps.NetworkFlag) or constants.SETTINGS.DEFAULT_NETWORK_FLAG
  local defaultNetworkSignal = (ps and ps.DefaultNetworkSignal) or constants.SETTINGS.DEFAULT_NETWORK_SIGNAL

  local s1 = getOrCreateSection(cb, constants.SECTIONS.CYBERSYN_PRIORITY)
  local s2 = getOrCreateSection(cb, constants.SECTIONS.NETWORK_MASK)

  if defaultPriority ~= 0 and s1 and not s1.get_slot(1).value then
    s1.set_slot(1, MakeFilter({ type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME }, defaultPriority))
  end

  if defaultNetworkFlag ~= 0 and s2 and not s2.get_slot(1).value then
    s2.set_slot(1, MakeFilter(defaultNetworkSignal, defaultNetworkFlag))
  end

  -- Always initialize Section 3 (first custom section group) for new combinator placement
  if cb.sections_count < 3 then
    cb.add_section("")
  end
end

---Fixes sections after pasting settings from a vanilla/external constant combinator.
---Shifts pasted vanilla sections to Section 3+ and restores Section 1 (Priority) and Section 2 (Network Mask).
---@param playerIndex? integer Player index for default settings.
function C2CC:FixPastedVanillaSections(playerIndex)
  local cb = self:GetControlBehavior()
  if not cb then return end

  -- 1. Backup all current sections copied from the vanilla combinator
  local savedSections = {}
  for i = 1, cb.sections_count do
    local sec = cb.sections[i]
    if sec and sec.valid then
      local filters = {}
      for slotIdx = 1, sec.filters_count do
        local flt = sec.get_slot(slotIdx)
        if flt and flt.value then
          filters[slotIdx] = {
            value = flt.value,
            min = flt.min
          }
        end
      end
      table.insert(savedSections, {
        group_name = sec.group or "",
        active = sec.active,
        filters = filters
      })
    end
  end

  -- 2. Clear all sections
  for i = cb.sections_count, 1, -1 do
    cb.remove_section(i)
  end

  -- 3. Initialize Section 1 (Priority) and Section 2 (Network Mask) using player defaults
  self:InitializeDefaults(false, playerIndex)

  -- 4. Shift and re-create all vanilla sections into Section 3+
  for i, saved in ipairs(savedSections) do
    local targetSec = nil
    if i == 1 and cb.sections_count >= 3 then
      targetSec = cb.sections[3]
      targetSec.group = saved.group_name
    else
      targetSec = cb.add_section(saved.group_name)
    end

    if targetSec and targetSec.valid then
      targetSec.active = saved.active
      for slotIdx, flt in pairs(saved.filters) do
        targetSec.set_slot(slotIdx, {
          value = flt.value,
          min = flt.min
        })
      end
    end
  end
end

C2CC.ToInt32 = ToInt32

return C2CC
