import type { SignalID } from 'factorio:runtime';
import type { LocalisedString } from 'factorio:runtime';

export const modPrefix = 'C2CC';

function loc(key: string, ...args: (string | number | LocalisedString)[]): LocalisedString {
  return [modPrefix + '.' + key, ...args];
}

export const INPUT_MODE = {
  COUNT: 'count',
  STACKS: 'stacks',
} as const;

export type InputMode = (typeof INPUT_MODE)[keyof typeof INPUT_MODE];

export const SETTINGS = {
  DEFAULT_NEGATIVE_SIGNALS: true,
  DEFAULT_PRIORITY: 10,
  DEFAULT_NETWORK_FLAG: 1,
  DEFAULT_STACKS: 0,
  DEFAULT_COUNT: 0,
  DEFAULT_INPUT_MODE: INPUT_MODE.COUNT as InputMode,
  DEFAULT_NETWORK_SIGNAL: { type: 'virtual' as const, name: 'signal-A' } as SignalID,
  CS_PRIORITY_NAME: 'cybersyn2-priority',
};

export const ENTITY_NAME = 'cybersyn2-constant-combinator';

export const GUI = {
  MAIN_ELEMENT_NAME: modPrefix + '.Main',
};

export const SECTIONS = {
  CYBERSYN_PRIORITY: 1,
  NETWORK_MASK: 2,
};

export const CAPTIONS = {
  TITLE: loc('title'),
  TAB_COMBINATOR: loc('tab-combinator'),
  TAB_SETTINGS: loc('tab-settings'),
  STATUS_WORKING: loc('status-working'),
  STATUS_DISABLED: loc('status-disabled'),
  OUTPUT_ON: loc('output-on'),
  OUTPUT_OFF: loc('output-off'),
  CYBERSYN_PARAMETERS: loc('cybersyn-parameters'),
  STATION_PRIORITY: loc('station-priority'),
  REQUEST_PRIORITY: loc('request-priority'),
  SUPPLY_PRIORITY: loc('supply-priority'),
  MIN_PRIORITY: loc('min-priority'),
  MAX_PRIORITY: loc('max-priority'),
  NETWORK_LIST_TITLE: loc('network-list-title'),
  OPEN_ENCODER: loc('open-encoder'),
  CLOSE_ENCODER: loc('close-encoder'),
  OPEN_NETWORKS: loc('open-networks'),
  CLOSE_NETWORKS: loc('close-networks'),
  OUTPUT_SIGNALS: loc('output-signals'),
  ITEMS_SUMMARY: (items: number, stacks: number): LocalisedString =>
    loc('items-summary', items, stacks),
  FLUIDS_SUMMARY: (fluids: number): LocalisedString => loc('fluids-summary', fluids),
  STACKS: loc('stacks'),
  COUNT: loc('count'),
  ADD_SECTION: loc('add-section'),
  RENAME_GROUP: loc('rename-group'),
  EXISTING_GROUPS: loc('existing-groups'),
  SAVE: loc('save'),
  CANCEL: loc('cancel'),
  PLAYER_SETTINGS: loc('player-settings'),
  NEGATIVE_SIGNALS: loc('negative-signals'),
  AUTO_QUERY_PRIORITIES: loc('auto-query-priorities'),
  DEFAULT_PRIORITY: loc('default-priority'),
  APPLY_PRIORITY_ALL: loc('apply-priority-all'),
  DEFAULT_NETWORK_SIGNAL: loc('default-network-signal'),
  DEFAULT_NETWORK_MASK: loc('default-network-mask'),
  APPLY_NETWORK_ALL: loc('apply-network-all'),
  DEFAULT_STACKS: loc('default-stacks'),
  DEFAULT_COUNT: loc('default-count'),
  DEFAULT_INPUT_MODE: loc('default-input-mode'),
  INPUT_MODE_COUNTS: loc('input-mode-counts'),
  INPUT_MODE_STACKS: loc('input-mode-stacks'),
  SAVE_SETTINGS: loc('save-settings'),
  ACTIVE_GLOBAL_NETWORKS: loc('active-global-networks'),
  NO_ACTIVE_NETWORKS: loc('no-active-networks'),
  ENCODER_ALL: loc('all'),
  ENCODER_NONE: loc('none'),
  ADMIN_BATCH_REPLACE: loc('admin-batch-replace'),
  REPLACE_PRIORITY_TITLE: loc('replace-priority-title'),
  OLD_PRIORITY: loc('old-priority'),
  NEW_PRIORITY: loc('new-priority'),
  APPLY_PRIORITY_BTN: loc('apply-priority-btn'),
  REPLACE_NETWORK_TITLE: loc('replace-network-title'),
  OLD_NETWORK: loc('old-network'),
  NEW_NETWORK: loc('new-network'),
  APPLY_NETWORK_BTN: loc('apply-network-btn'),
};
