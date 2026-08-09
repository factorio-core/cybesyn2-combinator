local constants = require "scripts.constants"

---@class C2CC.PlayerSettingsData
---@field NegativeSignals boolean Automatically make output item and fluid signals negative.
---@field Priority integer Default station priority value.
---@field DefaultNetworkSignal SignalID Default network mask signal prototype.
---@field NetworkFlag integer Default network mask bitmask value.
---@field Stacks integer Default output stacks count value.
---@field Count integer Default output items count value.
---@field DefaultInputMode string Default focused input mode ("count" or "stacks").

---@class C2CC.PlayerSettings : C2CC.PlayerSettingsData
local PlayerSettings = {}
PlayerSettings.__index = PlayerSettings

---@param playerIndex integer
---@return C2CC.PlayerSettings
function PlayerSettings.Get(playerIndex)
  storage.player_settings = storage.player_settings or {}
  local st = storage.player_settings[playerIndex]

  if not st then
    st = {}
    storage.player_settings[playerIndex] = st
  end

  if st.NegativeSignals == nil then st.NegativeSignals = true end
  if st.Priority == nil then st.Priority = constants.SETTINGS.DEFAULT_PRIORITY end
  if st.DefaultNetworkSignal == nil then st.DefaultNetworkSignal = constants.SETTINGS.DEFAULT_NETWORK_SIGNAL end
  if st.NetworkFlag == nil then st.NetworkFlag = constants.SETTINGS.DEFAULT_NETWORK_FLAG end
  if st.Stacks == nil then st.Stacks = constants.SETTINGS.DEFAULT_STACKS end
  if st.Count == nil then st.Count = constants.SETTINGS.DEFAULT_COUNT end
  if st.DefaultInputMode == nil then st.DefaultInputMode = constants.SETTINGS.DEFAULT_INPUT_MODE end

  setmetatable(st, PlayerSettings)
  return st
end

---@param playerIndex integer
---@return C2CC.PlayerSettings
function PlayerSettings.Copy(playerIndex)
  local src = PlayerSettings.Get(playerIndex)
  local draft = {}
  for k, v in pairs(src) do
    draft[k] = v
  end
  setmetatable(draft, PlayerSettings)
  return draft
end

---@param data table
function PlayerSettings:Update(data)
  if not data then return end
  if data.NegativeSignals ~= nil then self.NegativeSignals = data.NegativeSignals ~= false end
  if data.Priority ~= nil then self.Priority = tonumber(data.Priority) or constants.SETTINGS.DEFAULT_PRIORITY end
  if data.DefaultNetworkSignal ~= nil and data.DefaultNetworkSignal.name then self.DefaultNetworkSignal = data.DefaultNetworkSignal end
  if data.NetworkFlag ~= nil then self.NetworkFlag = tonumber(data.NetworkFlag) or constants.SETTINGS.DEFAULT_NETWORK_FLAG end
  if data.Stacks ~= nil then self.Stacks = tonumber(data.Stacks) or 0 end
  if data.Count ~= nil then self.Count = tonumber(data.Count) or 0 end
  if data.DefaultInputMode ~= nil then self.DefaultInputMode = tostring(data.DefaultInputMode) end
end

---@param playerIndex integer
---@param settingsData table
function PlayerSettings.Set(playerIndex, settingsData)
  if not playerIndex or not settingsData then return end
  local ps = PlayerSettings.Get(playerIndex)
  ps:Update(settingsData)
end

return PlayerSettings
