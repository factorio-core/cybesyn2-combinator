local constants = require "scripts.constants"
local PlayerSettings = require "scripts.models.player_settings"
local C2CC = require "scripts.models.combinator"
local utils = require "scripts.gui.utils"
local priorities = require "scripts.gui.priorities"

---@class C2CC.GuiMainState
---@field EditPriority string|nil
---@field EditNetworkValue string|nil
---@field EditItems string|number
---@field EditStacks string|number
---@field SelectedSection? integer
---@field SelectedSlot? integer
---@field ActiveTab string
---@field EncoderOpen boolean
---@field NetworksOpen boolean
---@field TargetFocusField string|nil

---@class C2CC.GuiSettingsState : C2CC.PlayerSettings
---@field ChangeOldPriority boolean
---@field ChangeOldNetwork boolean
---@field EncoderOpen boolean
---@field StatusMessage string
local GuiSettingsState = {}
GuiSettingsState.__index = GuiSettingsState

---@param playerIndex integer
---@return C2CC.GuiSettingsState
function GuiSettingsState.New(playerIndex)
  local base = PlayerSettings.Copy(playerIndex)
  base.ChangeOldPriority = true
  base.ChangeOldNetwork = true
  base.EncoderOpen = false
  base.StatusMessage = ""
  setmetatable(base, GuiSettingsState)
  return base
end

---@param playerIndex integer
function GuiSettingsState:Reset(playerIndex)
  local fresh = PlayerSettings.Copy(playerIndex)
  for k, v in pairs(fresh) do
    self[k] = util.table.deepcopy(v)
  end
  self.ChangeOldPriority = true
  self.ChangeOldNetwork = true
  self.EncoderOpen = false
  self.StatusMessage = ""
end

---@param val boolean
function GuiSettingsState:SetNegativeSignals(val) self.NegativeSignals = val end

---@param val number|string
function GuiSettingsState:SetPriority(val) self.Priority = val end

---@param val SignalID
function GuiSettingsState:SetDefaultNetworkSignal(val) self.DefaultNetworkSignal = val end

---@param val number|string
function GuiSettingsState:SetNetworkFlag(val) self.NetworkFlag = val end

---@param val number|string
function GuiSettingsState:SetStacks(val) self.Stacks = val end

---@param val number|string
function GuiSettingsState:SetCount(val) self.Count = val end

---@param val string
function GuiSettingsState:SetDefaultInputMode(val) self.DefaultInputMode = val end

---@param val boolean
function GuiSettingsState:SetAutoQueryPriorities(val) self.AutoQueryPriorities = val end

---@param val boolean
function GuiSettingsState:SetChangeOldPriority(val) self.ChangeOldPriority = val end

---@param val boolean
function GuiSettingsState:SetChangeOldNetwork(val) self.ChangeOldNetwork = val end

---@param val boolean
function GuiSettingsState:SetEncoderOpen(val) self.EncoderOpen = val end

---@class C2CC.GuiState
---@field Combinator C2CC
---@field PlayerSettings C2CC.PlayerSettings
---@field PlayerIndex integer
---@field GuiMain C2CC.GuiMainState
---@field GuiSettings C2CC.GuiSettingsState
local GuiState = {}
GuiState.__index = GuiState

---@param st table
---@param playerIndex integer
function GuiState.Validate(st, playerIndex)
  st.PlayerIndex = playerIndex
  st.PlayerSettings = PlayerSettings.Get(playerIndex)

  if not st.GuiMain then st.GuiMain = {} end
  local gm = st.GuiMain
  if gm.EditItems == nil then gm.EditItems = "" end
  if gm.EditStacks == nil then gm.EditStacks = "" end
  if gm.ActiveTab == nil then gm.ActiveTab = "combinator" end
  if gm.EncoderOpen == nil then gm.EncoderOpen = false end
  if gm.NetworksOpen == nil then gm.NetworksOpen = false end

  if not st.GuiSettings then
    st.GuiSettings = GuiSettingsState.New(playerIndex)
  end
end

---@param playerIndex integer
---@param entity? LuaEntity
---@return C2CC.GuiState
function GuiState.Get(playerIndex, entity)
  if not playerIndex then return nil end
  storage.gui_state = storage.gui_state or {}
  local st = storage.gui_state[playerIndex]
  if not st then
    st = {}
    storage.gui_state[playerIndex] = st
  end
  GuiState.Validate(st, playerIndex)
  setmetatable(st, GuiState)
  if entity and entity.valid then
    st.Combinator = C2CC:New(entity)
    st:InitEditBuffers()
    st:InitInitialFocus()
  end
  return st
end

---@param force? boolean Force reload edit buffers from current combinator entity and settings.
function GuiState:InitEditBuffers(force)
  if not self.GuiMain then self.GuiMain = {} end
  if self.Combinator then
    if force or self.GuiMain.EditPriority == nil then
      self.GuiMain.EditPriority = tostring(self.Combinator:GetPriority())
    end
    if force or self.GuiMain.EditNetworkValue == nil then
      self.GuiMain.EditNetworkValue = tostring(self:GetNetworkCount())
    end
  end

  local ps = self.PlayerSettings
  if force or self.GuiMain.EditItems == nil or self.GuiMain.EditItems == "" then
    self.GuiMain.EditItems = (ps and ps.Count and ps.Count ~= 0) and tostring(ps.Count) or ""
  end
  if force or self.GuiMain.EditStacks == nil or self.GuiMain.EditStacks == "" then
    self.GuiMain.EditStacks = (ps and ps.Stacks and ps.Stacks ~= 0) and tostring(ps.Stacks) or ""
  end
end

function GuiState:GetStatistics()
  local totalItems = 0
  local totalItemStacks = 0
  local totalFluids = 0
  if self.Combinator then
    for _, grp in ipairs(self.Combinator:GetGroups()) do
      if grp.IsActive then
        for _, sdata in pairs(grp.Slots) do
          if sdata and sdata.Signal then
            local sigType = sdata.Signal.type or "item"
            if sigType == "fluid" then
              totalFluids = totalFluids + math.abs(tonumber(sdata.Count) or 0)
            elseif sigType == "item" then
              local sSize = utils.get_stack_size(sdata.Signal)
              local c = tonumber(sdata.Count) or 0
              totalItems = totalItems + math.abs(c)
              totalItemStacks = totalItemStacks + math.ceil(math.abs(c) / sSize)
            end
          end
        end
      end
    end
  end
  return {
    totalItems = totalItems,
    totalItemStacks = totalItemStacks,
    totalFluids = totalFluids,
  }
end

---@return table
function GuiState:GetSignalPriorities()
  if not self.Combinator or not self.Combinator.Entity or not self.Combinator.Entity.valid then
    log("[c2cc] GetSignalPriorities: Combinator or Entity is invalid")
    return {}
  end
  if self.PlayerSettings and self.PlayerSettings.AutoQueryPriorities == false then
    log("[c2cc] GetSignalPriorities: AutoQueryPriorities is false")
    return {}
  end
  if self.PrioritiesCache == nil then
    log("[c2cc] GetSignalPriorities: cache nil, querying priorities...")
    local info = storage.opened_info and storage.opened_info[self.PlayerIndex]
    local cached_inv_ids = info and info.target_inv_ids or nil
    self.PrioritiesCache = priorities.query_signal_priorities(self.Combinator.Entity, cached_inv_ids)
  end
  return self.PrioritiesCache or {}
end

---@return boolean
function GuiState:IsStacksEnabled()
  if self.GuiMain.SelectedSection and self.GuiMain.SelectedSlot and self.Combinator then
    local sig = self.Combinator:GetGroupSlot(self.GuiMain.SelectedSection, self.GuiMain.SelectedSlot)
    if sig then
      return utils.is_stackable_signal(sig)
    end
  end
  return true
end

function GuiState:InitInitialFocus()
  if not self.GuiMain.HasFocusedInitial then
    self.GuiMain.HasFocusedInitial = true
    local isStacksEnabled = true
    if self.GuiMain.SelectedSection and self.GuiMain.SelectedSlot and self.Combinator then
      local sig = self.Combinator:GetGroupSlot(self.GuiMain.SelectedSection, self.GuiMain.SelectedSlot)
      if sig then
        isStacksEnabled = utils.is_stackable_signal(sig)
      end
    end
    local defaultMode = self.PlayerSettings.DefaultInputMode or constants.INPUT_MODE.COUNT
    if defaultMode == constants.INPUT_MODE.STACKS and isStacksEnabled then
      self.GuiMain.TargetFocusField = constants.GUI.FIELD_EDIT_STACKS
    else
      self.GuiMain.TargetFocusField = constants.GUI.FIELD_EDIT_COUNT
    end
  end
end

---@param signal SignalID|nil
---@return string
function GuiState:GetActiveInputMode(signal)
  local ps = self.PlayerSettings
  local defaultMode = ps.DefaultInputMode or constants.INPUT_MODE.COUNT
  if signal and signal.name and not utils.is_stackable_signal(signal) then
    return constants.INPUT_MODE.COUNT
  end
  return defaultMode
end

---@param textVal string|number|nil
---@param textVal string|number|nil
---@return string
function GuiState:FormatInputText(textVal)
  if textVal == nil or textVal == "" then return "" end
  local strVal = tostring(textVal)
  if strVal == "-" then return "-" end
  local num = tonumber(strVal)
  if not num then return strVal end

  if self.PlayerSettings and self.PlayerSettings.NegativeSignals then
    if num == 0 then return strVal end
    return "-" .. tostring(math.abs(num))
  else
    return strVal
  end
end

---@param signal SignalID|nil
---@param isStacksEdited boolean
---@return integer
function GuiState:ComputeFinalCount(signal, isStacksEdited)
  local gm = self.GuiMain
  local items = gm.EditItems
  local stacks = gm.EditStacks

  local isStackable = utils.is_stackable_signal(signal)
  local sSize = utils.get_stack_size(signal)

  local rawCount = 1
  if not isStackable then
    rawCount = tonumber(items) or 1
  else
    local stacksVal = tonumber(stacks)
    if (not stacksVal or stacksVal == 0) then
      local ps = self.PlayerSettings
      if ps.Stacks and ps.Stacks ~= 0 then
        stacksVal = ps.Stacks
      end
    end

    if isStacksEdited and stacksVal and stacksVal ~= 0 then
      rawCount = stacksVal * sSize
    elseif tonumber(items) and tonumber(items) ~= 0 then
      rawCount = tonumber(items)
    elseif stacksVal and stacksVal ~= 0 then
      rawCount = stacksVal * sSize
    else
      rawCount = sSize
    end
  end

  if self.PlayerSettings and self.PlayerSettings.NegativeSignals then
    return utils.to_int32(-math.abs(rawCount))
  else
    return utils.to_int32(rawCount)
  end
end

---Calculates the initial count for a signal when adding or setting a slot filter.
---@param signal SignalID|nil Signal prototype.
---@return integer # Formatted int32 count.
function GuiState:CalculateInitialSignalCount(signal)
  if not signal or not signal.name then return -1 end

  local ps = self.PlayerSettings
  local gm = self.GuiMain

  local isNegative = (ps and ps.NegativeSignals ~= false)

  local isStackable = utils.is_stackable_signal(signal)
  local sSize = utils.get_stack_size(signal)

  local activeMode = self:GetActiveInputMode(signal)
  local typedItems = tonumber(gm.EditItems)
  local typedStacks = tonumber(gm.EditStacks)

  local rawCount = nil

  if activeMode == constants.INPUT_MODE.STACKS and isStackable then
    -- In Stacks mode: prioritize typed Stacks over typed Items
    if typedStacks and typedStacks ~= 0 then
      rawCount = math.abs(typedStacks) * sSize
      if typedStacks < 0 then isNegative = true end
    elseif typedItems and typedItems ~= 0 then
      rawCount = math.abs(typedItems)
      if typedItems < 0 then isNegative = true end
    else
      local stks = (ps.Stacks and ps.Stacks ~= 0) and math.abs(ps.Stacks) or 1
      rawCount = stks * sSize
    end
  else
    -- In Count mode: prioritize typed Items over typed Stacks
    if typedItems and typedItems ~= 0 then
      rawCount = math.abs(typedItems)
      if typedItems < 0 then isNegative = true end
    elseif isStackable and typedStacks and typedStacks ~= 0 then
      rawCount = math.abs(typedStacks) * sSize
      if typedStacks < 0 then isNegative = true end
    else
      local cnt = (ps.Count and ps.Count ~= 0) and math.abs(ps.Count) or 1
      rawCount = cnt
    end
  end

  local finalCount = isNegative and -rawCount or rawCount
  return utils.to_int32(finalCount)
end

---@param signalOrCombinator SignalID|C2CC|nil
---@return string
function GuiState:GetTargetFocusFieldName(signalOrCombinator)
  local signal = nil
  if signalOrCombinator then
    if signalOrCombinator.GetGroupSlot then
      local gm = self.GuiMain
      if gm.SelectedSection and gm.SelectedSlot then
        signal = signalOrCombinator:GetGroupSlot(gm.SelectedSection, gm.SelectedSlot)
      end
    else
      signal = signalOrCombinator
    end
  end

  local activeMode = self:GetActiveInputMode(signal)
  if activeMode == constants.INPUT_MODE.STACKS then
    return constants.GUI.FIELD_EDIT_STACKS
  else
    return constants.GUI.FIELD_EDIT_COUNT
  end
end

---@param val string|nil
function GuiState:SetTargetFocusField(val)
  self.GuiMain.TargetFocusField = val
end

function GuiState:ToggleEnabled()
  self.Combinator:SetEnabled(not self.Combinator:IsEnabled())
end

---@param text string
function GuiState:SetCombinatorPriority(text)
  self.GuiMain.EditPriority = text
  local n = tonumber(text)
  if n then
    self.Combinator:SetPriority(n)
  end
end

---@param sig SignalID|nil
function GuiState:ChangeNetworkSignal(sig)
  if sig and sig.name then
    local count = tonumber(self.GuiMain.EditNetworkValue) or self:GetNetworkCount()
    self.Combinator:SetNetworkSignal({ Signal = sig, Count = count })
    self.GuiMain.EditNetworkValue = tostring(count)
  else
    self.Combinator:SetNetworkSignal(nil)
    self.GuiMain.EditNetworkValue = "0"
  end
end

function GuiState:GetNetworkCount()
  local net = self.Combinator:GetNetworkSignal()
  return net and tonumber(net.Count) or 0
end

---@param text string
function GuiState:ChangeNetworkValue(text)
  self.GuiMain.EditNetworkValue = text
  local n = tonumber(text)
  if not n then return end
  local net = self.Combinator:GetNetworkSignal()
  if net and net.Signal then
    self.Combinator:SetNetworkSignal({ Signal = net.Signal, Count = n })
  end
end

---@param sig SignalID
---@param count integer
function GuiState:SelectGlobalNetwork(sig, count)
  if sig and sig.name then
    self.Combinator:SetNetworkSignal({ Signal = sig, Count = count })
    self.GuiMain.NetworksOpen = false
    self.GuiMain.EditNetworkValue = tostring(count)
  end
end

function GuiState:ToggleEncoder()
  self.GuiMain.EncoderOpen = not self.GuiMain.EncoderOpen
  self.GuiMain.NetworksOpen = false
end

function GuiState:ToggleNetworks()
  self.GuiMain.NetworksOpen = not self.GuiMain.NetworksOpen
  self.GuiMain.EncoderOpen = false
end

---@param tab string
function GuiState:SetActiveTab(tab)
  self.GuiMain.ActiveTab = tab
end

function GuiState:AddGroup()
  self.Combinator:AddGroup("")
end

---@param secIdx integer
function GuiState:RemoveGroup(secIdx)
  self.Combinator:RemoveGroup(secIdx)
  self:SetSelectedSection(nil)
  self:SetSelectedSlot(nil)
end

---@param secIdx integer
---@param isActive boolean
function GuiState:SetGroupActive(secIdx, isActive)
  self.Combinator:SetGroupActive(secIdx, isActive)
end

---@param val integer|nil
function GuiState:SetSelectedSection(val)
  self.GuiMain.SelectedSection = val
end

---@param val integer|nil
function GuiState:SetSelectedSlot(val)
  self.GuiMain.SelectedSlot = val
end

function GuiState:ResetSelection()
  self.GuiMain.SelectedSection = nil
  self.GuiMain.SelectedSlot = nil
  self.GuiMain.TargetFocusField = nil
end

---@param text string
function GuiState:ChangeEditStacks(text)
  self.GuiMain.EditStacks = text

  local n = tonumber(text)
  if not n then return end

  local sec = self.GuiMain.SelectedSection
  local slot = self.GuiMain.SelectedSlot
  if not sec or not slot then return end

  local sig = self.Combinator:GetGroupSlot(sec, slot)
  if not sig or not sig.name then return end
  if not utils.is_stackable_signal(sig) then
    utils.focus_input_field(self.PlayerIndex, constants.GUI.FIELD_EDIT_COUNT)
    return
  end

  local sSize = utils.get_stack_size(sig)
  local count = n * sSize
  self.Combinator:SetGroupSlot(sec, slot, sig, count)
  self.GuiMain.EditItems = tostring(count)
end

---@param text string
function GuiState:ChangeEditItems(text)
  self.GuiMain.EditItems = text

  local n = tonumber(text)
  if not n then return end

  local sec = self.GuiMain.SelectedSection
  local slot = self.GuiMain.SelectedSlot
  if not sec or not slot then return end

  local sig = self.Combinator:GetGroupSlot(sec, slot)
  if not sig or not sig.name then return end

  self.Combinator:SetGroupSlot(sec, slot, sig, n)
  if utils.is_stackable_signal(sig) then
    local sSize = utils.get_stack_size(sig)
    self.GuiMain.EditStacks = tostring(math.ceil(math.abs(n) / sSize) * (n < 0 and -1 or 1))
  end
end

---@param secIdx integer
---@param slotIdx integer
function GuiState:OnSlotClicked(secIdx, slotIdx)
  local groups = self.Combinator:GetGroups()
  local targetGroup = nil
  for _, g in ipairs(groups) do
    if g.GroupIndex == secIdx then
      targetGroup = g
      break
    end
  end

  self:SetSelectedSection(secIdx)
  self:SetSelectedSlot(slotIdx)
  local targetField = nil

  if targetGroup and targetGroup.Slots and targetGroup.Slots[slotIdx] then
    local slotData = targetGroup.Slots[slotIdx]
    local sig = slotData.Signal
    if sig and sig.name then
      local rawCount = tonumber(slotData.Count) or 0
      self.GuiMain.EditItems = tostring(rawCount)
      if utils.is_stackable_signal(sig) then
        local sSize = utils.get_stack_size(sig)
        local displaySign = rawCount < 0 and -1 or 1
        self.GuiMain.EditStacks = tostring(displaySign * math.ceil(math.abs(rawCount) / sSize))
      end
      targetField = self:GetTargetFocusFieldName(sig)
    end
  end

  if targetField then
    self.GuiMain.TargetFocusField = targetField
  end
end

---@param isAdmin boolean
function GuiState:SaveSettings(isAdmin)
  local draft = self.GuiSettings
  local curPs = self.PlayerSettings
  local oldPriority = curPs.Priority
  local oldNetworkSignal = curPs.DefaultNetworkSignal
  local oldNetworkFlag = curPs.NetworkFlag

  local priorityChanged = (draft.Priority ~= oldPriority)
  local sameSignalType = (oldNetworkSignal and draft.DefaultNetworkSignal and (oldNetworkSignal.type or "item") == (draft.DefaultNetworkSignal.type or "item"))
  local sameSignalName = (oldNetworkSignal and draft.DefaultNetworkSignal and oldNetworkSignal.name == draft.DefaultNetworkSignal.name)
  local networkChanged = not (sameSignalType and sameSignalName and oldNetworkFlag == draft.NetworkFlag)

  PlayerSettings.Set(self.PlayerIndex, draft)

  local message = "Settings saved."
  if isAdmin and draft.ChangeOldPriority and priorityChanged then
    local updatedCount = utils.apply_priority_to_all_combinators(oldPriority, draft.Priority)
    message = message .. " Updated priority on " .. updatedCount .. " combinator(s)."
  end
  if isAdmin and draft.ChangeOldNetwork and networkChanged then
    local updatedNet = utils.apply_network_to_all_combinators(oldNetworkSignal, oldNetworkFlag, draft.DefaultNetworkSignal, draft.NetworkFlag)
    message = message .. " Updated network mask on " .. updatedNet .. " combinator(s)."
  end

  draft.StatusMessage = message
  self:InitEditBuffers(true)
end

function GuiState:CancelSettings()
  self.GuiSettings:Reset(self.PlayerIndex)
end

return GuiState
