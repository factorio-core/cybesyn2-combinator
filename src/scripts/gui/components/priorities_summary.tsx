import { useState, useRef, useInterval, createElement } from 'fcore/react';
import type { Color, LocalisedString, LuaGuiElement, PlayerIndex } from 'factorio:runtime';
import { SlotButton, SlotButtonTable, VFlow, ScrollPane } from 'fcore/react-components';
import { areObjectsEqual } from 'fcore/utils/table';
import { strace } from 'fcore/utils/strace';
import { querySignalPriorities, findStationForCombinator } from '../priorities';
import { PlayerSettings } from '../../models/player_settings';
import { CAPTIONS, SETTINGS, modPrefix } from '../../constants';
import { Combinator } from '../../models/combinator';

const C = CAPTIONS;

export interface PrioritiesSummaryProps {
  playerIndex: PlayerIndex;
  combinator: Combinator;
  highlightedSignalName?: string;
}

const COLOR_REQ_MIN = { r: 0.45, g: 0.75, b: 1.0 } as Color;
const COLOR_REQ_MAX = { r: 0.15, g: 0.4, b: 0.85 } as Color;
const COLOR_SUP_MIN = { r: 1.0, g: 0.55, b: 0.55 } as Color;
const COLOR_SUP_MAX = { r: 0.8, g: 0.2, b: 0.2 } as Color;

function priorityButton(
  val: number | undefined,
  colorTint: Color,
  tooltip: LocalisedString,
  key: string,
) {
  return (
    <SlotButton
      key={key}
      signal={{ type: 'virtual', name: SETTINGS.CS_PRIORITY_NAME }}
      locked={true}
      tooltip={tooltip}
      count={val !== undefined ? val : '-'}
      count_color={colorTint}
    />
  );
}

export function PrioritiesSummary(props: PrioritiesSummaryProps): any {
  const playerIndex = props.playerIndex;
  if (!playerIndex) return undefined;

  const ps = PlayerSettings.get(playerIndex);
  const comb = props.combinator;
  const entity = comb?.getEntity();

  strace.trace(
    modPrefix,
    'summary_render',
    'player',
    playerIndex,
    'autoQuery',
    ps.autoQueryPriorities,
    'combinator',
    entity?.unit_number,
  );

  if (ps.autoQueryPriorities === false) return undefined;
  if (!entity || !entity.valid) return undefined;

  const [cachedInvIds, setCachedInvIds] = useState<number[] | undefined>(() => {
    const [_, targetInvIds] = findStationForCombinator(entity);
    return targetInvIds;
  });

  const [prioritiesCache, setPrioritiesCache] = useState<SignalPriorityStat[]>(() =>
    querySignalPriorities(entity, cachedInvIds),
  );

  useInterval(() => {
    if (!entity.valid) return;
    let invIds = cachedInvIds;
    if (!invIds || invIds.length === 0) {
      const [_, resolved] = findStationForCombinator(entity);
      if (resolved && resolved.length > 0) {
        invIds = resolved;
        setCachedInvIds(resolved);
      }
    }
    const newPrio = querySignalPriorities(entity, invIds);
    if (!areObjectsEqual(prioritiesCache, newPrio)) {
      setPrioritiesCache(newPrio);
    }
  }, 120);

  if (!prioritiesCache || prioritiesCache.length === 0) return undefined;

  const highlighted = props.highlightedSignalName;
  const scrollPaneRef = useRef<LuaGuiElement>();

  const cells: any[] = [];
  for (const entry of prioritiesCache) {
    const sig = entry.signal;
    const reqMin = entry.reqFound ? (entry.reqMin ?? 0) : undefined;
    const reqMax = entry.reqFound ? (entry.reqMax ?? 0) : undefined;
    const supMin = entry.supFound ? (entry.supMin ?? 0) : undefined;
    const supMax = entry.supFound ? (entry.supMax ?? 0) : undefined;
    const isMatch = highlighted && sig.name === highlighted;
    const baseKey = (sig.type || 'item') + '-' + (sig.name || 'unknown');

    cells.push(
      <SlotButton
        key={baseKey + '-sig'}
        signal={sig}
        locked={true}
        selected={isMatch || undefined}
        ref={
          isMatch
            ? (el: any) => {
                if (el && el.valid && scrollPaneRef.current && scrollPaneRef.current.valid) {
                  (scrollPaneRef.current as any).scroll_to_element(el);
                }
              }
            : undefined
        }
      />,
    );

    cells.push(
      priorityButton(
        reqMin,
        COLOR_REQ_MIN,
        ['', C.REQUEST_PRIORITY, ' ', C.MIN_PRIORITY],
        baseKey + '-reqMin',
      ),
    );
    cells.push(
      priorityButton(
        reqMax,
        COLOR_REQ_MAX,
        ['', C.REQUEST_PRIORITY, ' ', C.MAX_PRIORITY],
        baseKey + '-reqMax',
      ),
    );
    cells.push(
      priorityButton(
        supMin,
        COLOR_SUP_MIN,
        ['', C.SUPPLY_PRIORITY, ' ', C.MIN_PRIORITY],
        baseKey + '-supMin',
      ),
    );
    cells.push(
      priorityButton(
        supMax,
        COLOR_SUP_MAX,
        ['', C.SUPPLY_PRIORITY, ' ', C.MAX_PRIORITY],
        baseKey + '-supMax',
      ),
    );
  }

  return (
    <VFlow styles={{ top_margin: 6, maximal_height: 90, minimal_height: 90 }}>
      <ScrollPane
        style="scroll_pane"
        vertical_scroll_policy="auto"
        horizontal_scroll_policy="never"
        styles={{
          horizontally_stretchable: true,
        }}
        ref={(el: any) => {
          scrollPaneRef.current = el;
        }}
      >
        <SlotButtonTable column_count={5}>{cells}</SlotButtonTable>
      </ScrollPane>
    </VFlow>
  );
}
