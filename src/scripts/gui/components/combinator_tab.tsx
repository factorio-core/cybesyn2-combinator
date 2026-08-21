import { createElement, useState, useEffect, useRef, useMemo, useInterval } from 'fcore/react';
import type { SignalID, ScrollPaneGuiElement, PlayerIndex } from 'factorio:runtime';
import {
  WellSection,
  Switch,
  Input,
  Button,
  SlotButton,
  SectionGroup,
  VFlow,
  HFlow,
  Label,
  ShallowSection,
  ScrollPane,
  Line,
} from 'fcore/react-components';
import { areObjectsEqual } from 'fcore/utils/table';
import { getStackSize, calculateInitialSignalCount } from '../utils';
import { Combinator } from '../../models/combinator';
import { PlayerSettings } from '../../models/player_settings';
import { CAPTIONS, SETTINGS, type InputMode } from '../../constants';
import { EncoderDialog } from './encoder_dialog';
import { NetworksDialog } from './networks_dialog';
import { PrioritiesSummary } from './priorities_summary';
import { SlotCountInputs } from './slot_count_inputs';

const C = CAPTIONS;

export interface CombinatorSnapshot {
  enabled: boolean;
  priority: number;
  netSignal?: SignalID;
  netCount: number;
  groups: SectionGroupData[];
}

function getCombinatorSnapshot(
  comb: Combinator,
  prevSnapshot?: CombinatorSnapshot,
): CombinatorSnapshot {
  const net = comb.getNetworkSignal();
  const enabled = comb.isEnabled();
  const priority = comb.getPriority();
  const netSignal = net?.signal;
  const netCount = net?.count || 0;

  const newGroups = comb.getGroups();
  let groups = newGroups;
  if (prevSnapshot && areObjectsEqual(prevSnapshot.groups, newGroups)) {
    groups = prevSnapshot.groups;
  }

  let stableNetSignal = netSignal;
  if (prevSnapshot && areObjectsEqual(prevSnapshot.netSignal, netSignal)) {
    stableNetSignal = prevSnapshot.netSignal;
  }

  if (
    prevSnapshot &&
    prevSnapshot.enabled === enabled &&
    prevSnapshot.priority === priority &&
    prevSnapshot.netCount === netCount &&
    prevSnapshot.netSignal === stableNetSignal &&
    prevSnapshot.groups === groups
  ) {
    return prevSnapshot;
  }

  return {
    enabled,
    priority,
    netSignal: stableNetSignal,
    netCount,
    groups,
  };
}

function getStatistics(groups: SectionGroupData[]) {
  let totalItems = 0;
  let totalItemStacks = 0;
  let totalFluids = 0;
  for (const group of groups) {
    if (group.isActive) {
      for (const [_, slot] of pairs(group.slots)) {
        if (slot && slot.signal && slot.signal.name) {
          const sigType = slot.signal.type || 'item';
          const count = Math.abs(slot.count || 0);
          if (sigType === 'fluid') {
            totalFluids += count;
          } else if (sigType === 'item') {
            totalItems += count;
            const sSize = getStackSize(slot.signal);
            totalItemStacks += sSize > 0 ? Math.ceil(count / sSize) : 0;
          }
        }
      }
    }
  }
  return { totalItems, totalItemStacks, totalFluids };
}

export interface CombinatorTabProps {
  playerIndex: PlayerIndex;
  combinator: Combinator;
}

export function CombinatorTab(props: CombinatorTabProps) {
  const { playerIndex, combinator: comb } = props;
  const player = game?.get_player(playerIndex);
  const ps = PlayerSettings.get(playerIndex);

  const [data, setData] = useState<CombinatorSnapshot>(() => getCombinatorSnapshot(comb));
  const update = () => setData((prev) => getCombinatorSnapshot(comb, prev));

  useInterval(() => {
    setData((prev) => getCombinatorSnapshot(comb, prev));
  }, 60);

  const [encoderOpen, setEncoderOpen] = useState(false);
  const [networksOpen, setNetworksOpen] = useState(false);

  const [selectedSlot, setSelectedSlot] = useState<
    { groupIndex: number; slotIndex: number } | undefined
  >(undefined);
  const [shouldScrollBottom, setShouldScrollBottom] = useState(false);
  const scrollPaneRef = useRef<ScrollPaneGuiElement>();
  const draftCountsRef = useRef<{ items?: string; stacks?: string }>({});

  useEffect(() => {
    if (shouldScrollBottom && scrollPaneRef.current && scrollPaneRef.current.valid) {
      scrollPaneRef.current.scroll_to_bottom();
      setShouldScrollBottom(false);
    }
  }, [shouldScrollBottom]);

  let activeSignal: SignalID | undefined = undefined;
  let activeCount = 0;
  if (selectedSlot) {
    const [sig, cnt] = comb.getGroupSlot(selectedSlot.groupIndex, selectedSlot.slotIndex);
    activeSignal = sig;
    activeCount = cnt || 0;
  }

  const handleSlotCountChange = (newCount: number) => {
    if (!selectedSlot) return;
    const [sig] = comb.getGroupSlot(selectedSlot.groupIndex, selectedSlot.slotIndex);
    if (!sig || !sig.name) return;
    comb.setGroupSlot(selectedSlot.groupIndex, selectedSlot.slotIndex, sig, newCount);
    update();
  };

  const handleSlotClick = (groupIndex: GroupIndex, slotIndex: SlotIndex) => {
    if (
      selectedSlot &&
      selectedSlot.groupIndex === groupIndex &&
      selectedSlot.slotIndex === slotIndex
    ) {
      setSelectedSlot(undefined);
    } else {
      setSelectedSlot({ groupIndex, slotIndex });
    }
  };

  const handleSlotChange = (groupIndex: GroupIndex, slotIndex: SlotIndex, sig?: SignalID) => {
    if (sig && sig.name) {
      const initialCount = calculateInitialSignalCount(
        sig,
        playerIndex,
        draftCountsRef.current.items,
        draftCountsRef.current.stacks,
      );
      comb.setGroupSlot(groupIndex, slotIndex, sig, initialCount);
      setSelectedSlot({ groupIndex, slotIndex });
    } else {
      comb.setGroupSlot(groupIndex, slotIndex, undefined, 0);
      if (
        selectedSlot &&
        selectedSlot.groupIndex === groupIndex &&
        selectedSlot.slotIndex === slotIndex
      ) {
        setSelectedSlot(undefined);
      }
    }
    update();
  };

  const groupElements: any[] = [];
  for (let i = 0; i < data.groups.length; i++) {
    const grp = data.groups[i];
    groupElements.push(
      <SectionGroup
        key={`grp-${grp.uid || grp.groupIndex}`}
        name={grp.rawGroupName}
        active={grp.isActive}
        slots={grp.slots}
        selectedSlot={
          selectedSlot && selectedSlot.groupIndex === grp.groupIndex
            ? selectedSlot.slotIndex
            : undefined
        }
        tableStyle="slot_table"
        onActiveChange={(active) => {
          comb.setGroupActive(grp.groupIndex, active);
          update();
        }}
        onNameChange={(newName: string) => {
          comb.renameGroup(grp.groupIndex, newName);
          update();
        }}
        onSlotClick={(slotIndex) => handleSlotClick(grp.groupIndex, slotIndex)}
        onSlotChange={(slotIndex, sig) => handleSlotChange(grp.groupIndex, slotIndex, sig)}
        onDelete={() => {
          comb.removeGroup(grp.groupIndex);
          if (selectedSlot && selectedSlot.groupIndex === grp.groupIndex) {
            setSelectedSlot(undefined);
          }
          update();
        }}
      />,
    );
  }

  const stats = useMemo(() => getStatistics(data.groups), [data.groups]);
  const networkValue = tostring(data.netCount || 0);

  return (
    <VFlow>
      {/* 1. Status Switch */}
      <ShallowSection>
        <Switch
          switch_state={data.enabled ? 'right' : 'left'}
          left_label_caption={C.OUTPUT_OFF}
          right_label_caption={C.OUTPUT_ON}
          onChange={() => {
            comb.setEnabled(!data.enabled);
            update();
          }}
        />
      </ShallowSection>

      {/* 2. Priority Parameters */}
      <WellSection caption={C.CYBERSYN_PARAMETERS}>
        <VFlow>
          <HFlow styles={{ vertical_align: 'center' }}>
            <SlotButton
              signal={{ type: 'virtual', name: SETTINGS.CS_PRIORITY_NAME }}
              count={data.priority}
              locked={true}
            />
            <Label style="caption_label" caption={C.STATION_PRIORITY} />
            <Input
              text={tostring(data.priority || 0)}
              numeric={true}
              allow_negative={true}
              lose_focus_on_confirm={false}
              styles={{ width: 80 }}
              onChange={(val) => {
                comb.setPriority(tonumber(val) ?? 0);
                update();
              }}
            />
          </HFlow>
          <PrioritiesSummary
            playerIndex={playerIndex}
            combinator={comb}
            highlightedSignalName={
              selectedSlot
                ? data.groups.find((g) => g.groupIndex === selectedSlot.groupIndex)?.slots[
                    selectedSlot.slotIndex
                  ]?.signal?.name
                : undefined
            }
          />
        </VFlow>
      </WellSection>

      {/* 3. Network Mask */}
      <WellSection caption={C.NETWORK_LIST_TITLE}>
        <VFlow>
          <HFlow styles={{ vertical_align: 'center' }}>
            <SlotButton
              signal={data.netSignal}
              count={data.netCount}
              onChange={(sig: any) => {
                if (sig && sig.name) {
                  const currentCount = tonumber(networkValue) || data.netCount || 0;
                  comb.setNetworkSignal({
                    signal: sig as SignalID,
                    count: currentCount,
                  });
                } else {
                  comb.setNetworkSignal(undefined);
                }
                update();
              }}
            />
            <Input
              text={networkValue}
              numeric={true}
              allow_negative={true}
              lose_focus_on_confirm={false}
              styles={{ width: 80 }}
              onChange={(val) => {
                const n = tonumber(val);
                if (n !== undefined) {
                  const currentNet = comb.getNetworkSignal();
                  if (currentNet && currentNet.signal) {
                    comb.setNetworkSignal({ signal: currentNet.signal, count: n });
                  }
                }
                update();
              }}
            />
            <Button
              caption={encoderOpen ? C.CLOSE_ENCODER : C.OPEN_ENCODER}
              style={encoderOpen ? 'red_button' : 'button'}
              onClick={() => {
                setEncoderOpen(!encoderOpen);
                setNetworksOpen(false);
              }}
            />
            <Button
              caption={networksOpen ? C.CLOSE_NETWORKS : C.OPEN_NETWORKS}
              style={networksOpen ? 'red_button' : 'button'}
              onClick={() => {
                setNetworksOpen(!networksOpen);
                setEncoderOpen(false);
              }}
            />
          </HFlow>

          {encoderOpen && (
            <EncoderDialog
              mask={tonumber(networkValue) || 0}
              onChangeMask={(newMask: number) => {
                const currentNet = comb.getNetworkSignal();
                const sig = currentNet?.signal || {
                  type: 'virtual',
                  name: 'signal-check',
                };
                comb.setNetworkSignal({ signal: sig as SignalID, count: newMask });
                update();
              }}
            />
          )}

          {networksOpen && (
            <NetworksDialog
              onSelectNetwork={(sig: SignalID | undefined, selectedCount: number) => {
                comb.setNetworkSignal({ signal: sig as SignalID, count: selectedCount });
                setNetworksOpen(false);
                update();
              }}
            />
          )}
        </VFlow>
      </WellSection>

      {/* 4. Output Signals */}
      <WellSection caption={C.OUTPUT_SIGNALS}>
        <VFlow>
          <HFlow styles={{ vertical_align: 'center', bottom_margin: 6 }}>
            <ShallowSection>
              <Label caption={C.ITEMS_SUMMARY(stats.totalItems, stats.totalItemStacks)} />
            </ShallowSection>
            <ShallowSection>
              <Label caption={C.FLUIDS_SUMMARY(stats.totalFluids)} />
            </ShallowSection>
          </HFlow>

          <SlotCountInputs
            playerIndex={playerIndex}
            signal={activeSignal}
            count={activeCount || 0}
            defaultMode={ps.defaultInputMode as InputMode}
            onChange={handleSlotCountChange}
            onDraftChange={(items, stacks) => {
              draftCountsRef.current = { items, stacks };
            }}
          />

          <ScrollPane
            ref={(elem) => {
              scrollPaneRef.current = elem;
            }}
            style="naked_scroll_pane"
            vertical_scroll_policy="auto"
            horizontal_scroll_policy="never"
            styles={{
              horizontally_stretchable: true,
              extra_right_padding_when_activated: 4,
            }}
          >
            <VFlow
              styles={{
                horizontally_stretchable: true,
                horizontally_squashable: false,
              }}
            >
              {groupElements}
            </VFlow>
          </ScrollPane>

          <Button
            caption={C.ADD_SECTION}
            styles={{ horizontally_stretchable: true, top_margin: 4 }}
            onClick={() => {
              setSelectedSlot(undefined);
              comb.addGroup('');
              update();
              setShouldScrollBottom(true);
            }}
          />
        </VFlow>
      </WellSection>
    </VFlow>
  );
}
