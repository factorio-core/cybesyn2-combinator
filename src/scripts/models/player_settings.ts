import { SETTINGS } from '../constants';
import type { SignalID, PlayerIndex } from 'factorio:runtime';

export class PlayerSettings implements PlayerSettingsData {
  public negativeSignals: boolean = SETTINGS.DEFAULT_NEGATIVE_SIGNALS;
  public priority: Priority = SETTINGS.DEFAULT_PRIORITY;
  public defaultNetworkSignal?: SignalID = SETTINGS.DEFAULT_NETWORK_SIGNAL;
  public networkFlag: NetworkMask = SETTINGS.DEFAULT_NETWORK_FLAG;
  public stacks: number = SETTINGS.DEFAULT_STACKS;
  public count: number = SETTINGS.DEFAULT_COUNT;
  public defaultInputMode: string = SETTINGS.DEFAULT_INPUT_MODE;
  public autoQueryPriorities: boolean = true;

  constructor(init?: Partial<PlayerSettingsData>) {
    if (init) {
      Object.assign(this, init);
    }
  }

  public static get(playerIndex: PlayerIndex): PlayerSettings {
    const raw = storage.player_settings?.[playerIndex];
    const res = new PlayerSettings();
    if (raw) {
      res.negativeSignals = raw.negativeSignals ?? SETTINGS.DEFAULT_NEGATIVE_SIGNALS;
      res.priority = raw.priority ?? SETTINGS.DEFAULT_PRIORITY;
      res.defaultNetworkSignal = raw.defaultNetworkSignal ?? SETTINGS.DEFAULT_NETWORK_SIGNAL;
      res.networkFlag = raw.networkFlag ?? SETTINGS.DEFAULT_NETWORK_FLAG;
      res.stacks = raw.stacks ?? SETTINGS.DEFAULT_STACKS;
      res.count = raw.count ?? SETTINGS.DEFAULT_COUNT;
      res.defaultInputMode = raw.defaultInputMode ?? SETTINGS.DEFAULT_INPUT_MODE;
      res.autoQueryPriorities = raw.autoQueryPriorities ?? true;
    }
    return res;
  }

  public static copy(playerIndex: PlayerIndex): PlayerSettings {
    return new PlayerSettings(PlayerSettings.get(playerIndex));
  }

  public update(data?: Partial<PlayerSettingsData>): void {
    if (!data) return;
    if (data.negativeSignals !== undefined) this.negativeSignals = data.negativeSignals;
    if (data.priority !== undefined)
      this.priority = tonumber(data.priority) || SETTINGS.DEFAULT_PRIORITY;
    if (data.defaultNetworkSignal?.name) this.defaultNetworkSignal = data.defaultNetworkSignal;
    if (data.networkFlag !== undefined)
      this.networkFlag = tonumber(data.networkFlag) || SETTINGS.DEFAULT_NETWORK_FLAG;
    if (data.stacks !== undefined) this.stacks = tonumber(data.stacks) || 0;
    if (data.count !== undefined) this.count = tonumber(data.count) || 0;
    if (data.defaultInputMode !== undefined)
      this.defaultInputMode = tostring(data.defaultInputMode);
    if (data.autoQueryPriorities !== undefined) this.autoQueryPriorities = data.autoQueryPriorities;
  }

  public static set(playerIndex: PlayerIndex, settingsData: Partial<PlayerSettingsData>): void {
    if (!playerIndex || !settingsData) return;
    if (!storage.player_settings) storage.player_settings = {};
    const current = PlayerSettings.get(playerIndex);
    current.update(settingsData);
    storage.player_settings[playerIndex] = {
      negativeSignals: current.negativeSignals,
      priority: current.priority,
      defaultNetworkSignal: current.defaultNetworkSignal,
      networkFlag: current.networkFlag,
      stacks: current.stacks,
      count: current.count,
      defaultInputMode: current.defaultInputMode,
      autoQueryPriorities: current.autoQueryPriorities,
    };
  }
}
