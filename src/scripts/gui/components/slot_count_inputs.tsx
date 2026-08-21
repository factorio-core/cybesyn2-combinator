import { createElement, useState, useEffect, useRef } from 'fcore/react';
import { HFlow, Label, Input } from 'fcore/react-components';
import { CAPTIONS, INPUT_MODE, type InputMode } from '../../constants';
import { PlayerSettings } from '../../models/player_settings';
import { getStackSize, isStackableSignal, formatInputText } from '../utils';
import type { SignalID, LuaGuiElement, TextFieldGuiElement, PlayerIndex } from 'factorio:runtime';

const C = CAPTIONS;

export interface SlotCountInputsProps {
  playerIndex: PlayerIndex;
  signal?: SignalID;
  count: number;
  defaultMode?: InputMode;
  onChange: (this: void, newCount: number) => void;
  onDraftChange?: (this: void, items: string, stacks: string) => void;
}

export function SlotCountInputs(props: SlotCountInputsProps) {
  const {
    playerIndex,
    signal,
    count,
    defaultMode = INPUT_MODE.COUNT,
    onChange,
    onDraftChange,
  } = props;

  const ps = PlayerSettings.get(playerIndex);
  const isNeg = ps.negativeSignals !== false;

  const hasSignal = signal !== undefined && signal.name !== undefined && signal.name !== '';
  const isStackable = hasSignal ? isStackableSignal(signal) : true;
  const stackSize = hasSignal ? getStackSize(signal) : 1;

  const defItems = ps.count && ps.count !== 0 ? tostring(ps.count) : '';
  const defStacks = ps.stacks && ps.stacks !== 0 ? tostring(ps.stacks) : '';

  const [editItems, setEditItems] = useState<string>(() => {
    if (hasSignal) return tostring(count);
    return defItems;
  });

  const [editStacks, setEditStacks] = useState<string>(() => {
    if (hasSignal && isStackable && stackSize > 0) {
      const displaySign = count < 0 ? -1 : 1;
      return tostring(displaySign * Math.ceil(Math.abs(count) / stackSize));
    }
    return defStacks;
  });

  const stacksRef = useRef<TextFieldGuiElement>();
  const countRef = useRef<TextFieldGuiElement>();

  // When selected slot or signal or count changes externally
  useEffect(() => {
    if (hasSignal) {
      setEditItems(tostring(count));
      if (isStackable && stackSize > 0) {
        const displaySign = count < 0 ? -1 : 1;
        setEditStacks(tostring(displaySign * Math.ceil(Math.abs(count) / stackSize)));
      } else {
        setEditStacks('');
      }
    } else {
      setEditItems(defItems);
      setEditStacks(defStacks);
    }
  }, [signal?.name, signal?.type, count, ps.negativeSignals, ps.count, ps.stacks]);

  // Focus appropriate input on mount or signal change
  useEffect(() => {
    const shouldFocusStacks = defaultMode === INPUT_MODE.STACKS && isStackable;
    const el = shouldFocusStacks ? stacksRef.current : countRef.current;
    if (el && el.valid) {
      el.focus();
      (el as any).select_all?.();
    }
  }, [signal?.name, signal?.type, defaultMode]);

  const handleStacksChange = (text: string) => {
    setEditStacks(text);
    const n = tonumber(text);
    if (n === undefined) {
      if (onDraftChange) onDraftChange(editItems, text);
      return;
    }

    if (!isStackable || stackSize <= 0) return;

    const finalCount = isNeg && n > 0 ? -(n * stackSize) : n * stackSize;
    const finalItemsStr = tostring(finalCount);
    setEditItems(finalItemsStr);

    if (hasSignal) {
      onChange(finalCount);
    } else {
      if (onDraftChange) onDraftChange(finalItemsStr, text);
    }
  };

  const handleItemsChange = (text: string) => {
    setEditItems(text);
    const n = tonumber(text);
    if (n === undefined) {
      if (onDraftChange) onDraftChange(text, editStacks);
      return;
    }

    const finalCount = isNeg && n > 0 ? -n : n;

    let finalStacksStr = editStacks;
    if (isStackable && stackSize > 0) {
      const displaySign = finalCount < 0 ? -1 : 1;
      finalStacksStr = tostring(displaySign * Math.ceil(Math.abs(finalCount) / stackSize));
      setEditStacks(finalStacksStr);
    }

    if (hasSignal) {
      onChange(finalCount);
    } else {
      if (onDraftChange) onDraftChange(text, finalStacksStr);
    }
  };

  return (
    <HFlow styles={{ vertical_align: 'center', bottom_margin: 6 }}>
      <Label style="caption_label" caption={C.STACKS} />
      <Input
        ref={stacksRef}
        text={formatInputText(editStacks, isNeg)}
        numeric={true}
        allow_negative={true}
        enabled={isStackable}
        styles={{ width: 65 }}
        onChange={handleStacksChange}
      />
      <Label style="caption_label" caption={C.COUNT} />
      <Input
        ref={countRef}
        text={formatInputText(editItems, isNeg)}
        numeric={true}
        allow_negative={true}
        styles={{ width: 65 }}
        onChange={handleItemsChange}
      />
    </HFlow>
  );
}
