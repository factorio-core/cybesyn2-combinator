import { toInt32 } from '../models/combinator';
import { PlayerSettings } from '../models/player_settings';
import { ENTITY_NAME, INPUT_MODE } from '../constants';
import type { LuaEntity, SignalID, PlayerIndex } from 'factorio:runtime';

export { toInt32 };

/**
 * Checks if the entity is a valid Cybersyn2 Constant Combinator (or its ghost).
 */
export function isCombinatorEntity(entity?: LuaEntity): boolean {
  if (!entity || !entity.valid) return false;
  if (entity.name === ENTITY_NAME) return true;
  if (entity.name === 'entity-ghost' && entity.ghost_name === ENTITY_NAME) return true;
  return false;
}

/**
 * Determines whether a signal can be stacked (i.e. physical item vs virtual/fluid/quality).
 */
export function isStackableSignal(signal?: SignalID): boolean {
  if (!signal || !signal.name) return false;
  if (
    signal.type === 'fluid' ||
    signal.type === 'virtual' ||
    (signal.type as string) === 'quality'
  ) {
    return false;
  }
  return true;
}

/**
 * Reads the stack size of an item signal from Factorio prototypes.
 */
export function getStackSize(signal?: SignalID): number {
  if (!signal || !signal.name || signal.type === 'fluid' || signal.type === 'virtual') return 1;
  const name = signal.name;
  if (typeof prototypes !== 'undefined' && prototypes?.item?.[name]) {
    return prototypes.item[name].stack_size || 1;
  }
  return 1;
}

/**
 * Formats numeric input text, preserving leading minus sign when negative signals are enabled.
 */
export function formatInputText(
  textVal: string | number | undefined,
  isNegativeSignals?: boolean,
): string {
  if (textVal === undefined || textVal === '') return '';
  const strVal = tostring(textVal);
  if (strVal === '-') return '-';
  const num = tonumber(strVal);
  if (num === undefined) return strVal;

  if (isNegativeSignals) {
    if (num === 0) return strVal;
    return '-' + tostring(Math.abs(num));
  } else {
    return strVal;
  }
}

/**
 * Calculates initial slot count based on selected signal, player settings, and active input mode.
 */
export function calculateInitialSignalCount(
  signal: SignalID | undefined,
  playerIndex: PlayerIndex,
  typedItemsStr?: string,
  typedStacksStr?: string,
): number {
  if (!signal || !signal.name) return -1;

  const ps = PlayerSettings.get(playerIndex);
  let isNegative = ps.negativeSignals !== false;

  const isStackable = isStackableSignal(signal);
  const sSize = getStackSize(signal);

  const activeMode = !isStackable ? INPUT_MODE.COUNT : ps.defaultInputMode || INPUT_MODE.COUNT;

  const typedItems =
    typedItemsStr && typedItemsStr !== '' && typedItemsStr !== '-'
      ? tonumber(typedItemsStr)
      : undefined;
  const typedStacks =
    typedStacksStr && typedStacksStr !== '' && typedStacksStr !== '-'
      ? tonumber(typedStacksStr)
      : undefined;

  let rawCount: number;

  if (activeMode === INPUT_MODE.STACKS && isStackable) {
    if (typedStacks !== undefined && typedStacks !== 0) {
      rawCount = Math.abs(typedStacks) * sSize;
      if (typedStacks < 0) isNegative = true;
    } else if (typedItems !== undefined && typedItems !== 0) {
      rawCount = Math.abs(typedItems);
      if (typedItems < 0) isNegative = true;
    } else {
      const stks = ps.stacks && ps.stacks !== 0 ? ps.stacks : 1;
      rawCount = Math.abs(stks) * sSize;
      if (stks < 0) isNegative = true;
    }
  } else {
    if (typedItems !== undefined && typedItems !== 0) {
      rawCount = Math.abs(typedItems);
      if (typedItems < 0) isNegative = true;
    } else if (isStackable && typedStacks !== undefined && typedStacks !== 0) {
      rawCount = Math.abs(typedStacks) * sSize;
      if (typedStacks < 0) isNegative = true;
    } else {
      const cnt = ps.count && ps.count !== 0 ? ps.count : 1;
      rawCount = Math.abs(cnt);
      if (cnt < 0) isNegative = true;
    }
  }

  const finalCount = isNegative ? -rawCount : rawCount;
  return toInt32(finalCount);
}
