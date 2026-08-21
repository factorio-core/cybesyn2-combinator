import type { PlayerIndex, SignalID, LuaEntity } from 'factorio:runtime';
import type { Combinator } from './scripts/models/combinator';

declare global {
  type Priority = number;
  type NetworkMask = number;
  type GroupIndex = number;
  type SlotIndex = number;

  interface Storage {
    player_settings?: Record<PlayerIndex, PlayerSettingsData | undefined>;
  }

  const storage: Storage;
  type uint32 = number;
  type int32 = number;
  type uint8 = number;

  // 1. Player Settings Data
  interface PlayerSettingsData {
    priority: Priority;
    defaultNetworkSignal?: SignalID;
    networkFlag: NetworkMask;
    stacks: number;
    count: number;
    negativeSignals: boolean;
    defaultInputMode: string;
    autoQueryPriorities: boolean;
  }

  // 2. Combinator & Logistic Section Types
  interface NetworkSignal {
    signal: SignalID;
    count: number;
  }

  interface SectionGroupSlot {
    signal: SignalID;
    count: number;
  }

  interface SectionGroupData {
    uid?: number;
    groupIndex: GroupIndex;
    groupName: string;
    rawGroupName: string;
    isActive: boolean;
    maxSlotFound: number;
    slots: Record<SlotIndex, SectionGroupSlot | undefined>;
  }

  // 3. Priorities & Network Query Types
  interface SignalPriorityStat {
    signal: SignalID;
    reqMin?: Priority;
    reqMax?: Priority;
    reqFound: boolean;
    supMin?: Priority;
    supMax?: Priority;
    supFound: boolean;
  }

  interface ActiveNetworkEntry {
    signal: SignalID;
    count: number;
  }

  // 4. GUI Component Props
  interface MainProps {
    entity: LuaEntity;
    playerIndex: PlayerIndex;
  }

  interface SectionGroupProps {
    grp: SectionGroupData;
    groupsCount: number;
    selectedSection?: GroupIndex;
    selectedSlot?: SlotIndex;
    combinator?: Combinator;
    playerIndex: PlayerIndex;
    onSelectSlot?: (this: void, sectionIndex: GroupIndex, slotIndex: SlotIndex) => void;
    onResetSelection?: (this: void) => void;
    targetFocusField?: string;
    onClearTargetFocusField?: (this: void) => void;
  }

  interface EncoderDialogProps {
    mask?: NetworkMask;
    onChangeMask?: (this: void, mask: NetworkMask) => void;
    onApply?: (this: void, mask: NetworkMask) => void;
  }

  interface NetworksDialogProps {
    networks: ActiveNetworkEntry[];
    onSelectNetwork?: (this: void, signal: SignalID | undefined, count: number) => void;
    onClose?: (this: void) => void;
  }

  interface PrioritiesSummaryProps {
    playerIndex: PlayerIndex;
    combinator?: Combinator;
    highlightedSignalName?: string;
  }

  interface SettingsTabProps {
    playerIndex: PlayerIndex;
  }
}
