import { Combinator } from '../models/combinator';
import { strace } from 'fcore/utils/strace';
import { modPrefix } from '../constants';
import type { SignalID, LuaEntity, BoundingBox } from 'factorio:runtime';

/**
 * Resolves active Cybersyn 2 remote interface.
 */
export function getCybersynInterface(): string | undefined {
  if (typeof remote === 'undefined' || !remote.interfaces) return undefined;
  if (remote.interfaces['cybersyn2']) return 'cybersyn2';
  return undefined;
}

const signalKeyCache: Record<string, SignalID | undefined> = {};

/**
 * Parses signal keys from Cybersyn 2 into structured SignalID with memoization.
 * Format: "name" (normal quality) or "name|quality".
 */
export function parseSignalKey(key: string): SignalID | undefined {
  if (!key || typeof key !== 'string' || key === '') return undefined;
  if (signalKeyCache[key] !== undefined) {
    return signalKeyCache[key];
  }

  let sigName = key;
  let sigQuality: string | undefined = undefined;

  const pipeIndex = sigName.indexOf('|');
  if (pipeIndex !== -1) {
    const q = sigName.substring(pipeIndex + 1);
    sigName = sigName.substring(0, pipeIndex);
    if (q !== 'normal') {
      sigQuality = q;
    }
  }

  let sigType:
    | 'item'
    | 'fluid'
    | 'virtual'
    | 'quality'
    | 'entity'
    | 'recipe'
    | 'space-location'
    | 'asteroid-chunk'
    | undefined = undefined;

  if (prototypes.item && prototypes.item[sigName] !== undefined) {
    sigType = 'item';
  } else if (prototypes.fluid && prototypes.fluid[sigName] !== undefined) {
    sigType = 'fluid';
  } else if (prototypes.virtual_signal && prototypes.virtual_signal[sigName] !== undefined) {
    sigType = 'virtual';
  } else if (prototypes.quality && prototypes.quality[sigName] !== undefined) {
    sigType = 'quality';
  } else if (prototypes.entity && prototypes.entity[sigName] !== undefined) {
    sigType = 'entity';
  } else if (prototypes.recipe && prototypes.recipe[sigName] !== undefined) {
    sigType = 'recipe';
  } else if (prototypes.space_location && prototypes.space_location[sigName] !== undefined) {
    sigType = 'space-location';
  } else if (prototypes.asteroid_chunk && prototypes.asteroid_chunk[sigName] !== undefined) {
    sigType = 'asteroid-chunk';
  } else {
    signalKeyCache[key] = undefined;
    return undefined;
  }

  const result: SignalID = {
    type: sigType as any,
    name: sigName,
    quality: sigQuality as any,
  };
  signalKeyCache[key] = result;
  return result;
}

/**
 * Finds the Cybersyn station associated with the combinator by nearby train-stop or rails.
 */
export function findStationForCombinator(
  entity: LuaEntity,
): LuaMultiReturn<[number | undefined, number[]]> {
  const csInterface = getCybersynInterface();
  if (!entity || !entity.valid || !csInterface) {
    strace.trace(
      modPrefix,
      'find_station_skip',
      'valid',
      entity?.valid,
      'csInterface',
      csInterface,
    );
    return $multi(undefined, []);
  }

  const pos = entity.position as any;
  const px = (pos.x ?? pos[0]) as number;
  const py = (pos.y ?? pos[1]) as number;

  const searchArea: BoundingBox = {
    left_top: { x: px - 3.5, y: py - 3.5 },
    right_bottom: { x: px + 3.5, y: py + 3.5 },
  };

  // 1. Direct train-stop in 3.5 tile radius
  const nearbyStops = entity.surface.find_entities_filtered({
    area: searchArea,
    type: 'train-stop',
  });

  let stopUnit = nearbyStops[0]?.unit_number;

  // 2. If no direct train-stop, check nearby rails and match Cybersyn stops
  if (!stopUnit) {
    const nearbyRails = entity.surface.find_entities_filtered({
      area: searchArea,
      type: [
        'legacy-straight-rail',
        'straight-rail-horizontal',
        'straight-rail-vertical',
        'half-diagonal-rail',
        'curved-rail-a',
        'curved-rail-b',
        'rail-ramp',
        'elevated-straight-rail',
        'elevated-curved-rail-a',
        'elevated-curved-rail-b',
        'elevated-half-diagonal-rail',
      ] as any,
    });
    if (nearbyRails.length > 0) {
      const stopsAll = remote.call(csInterface, 'query', { type: 'stops', all: true }) as any;
      if (stopsAll && stopsAll.data) {
        for (const s of stopsAll.data) {
          const sEnt = s.entity;
          if (sEnt && sEnt.valid && sEnt.surface.index === entity.surface.index) {
            const sPos = sEnt.position as any;
            const sx = (sPos.x ?? sPos[0]) as number;
            const sy = (sPos.y ?? sPos[1]) as number;
            const dx = sx - px;
            const dy = sy - py;
            if (dx * dx + dy * dy <= 100) {
              stopUnit = s.entity_id || sEnt.unit_number;
              break;
            }
          }
        }
      }
    }
  }

  if (!stopUnit) {
    strace.trace(
      modPrefix,
      'find_station_none',
      'combinator',
      entity.unit_number,
      'pos_x',
      px,
      'pos_y',
      py,
    );
    return $multi(undefined, []);
  }

  const stopRes = remote.call(csInterface, 'query', {
    type: 'stops',
    unit_numbers: [stopUnit],
  }) as any;
  const stopList = stopRes && stopRes.data;
  let stopObj: any = undefined;
  if (stopList) {
    for (const s of stopList) {
      if (s) {
        stopObj = s;
        break;
      }
    }
  }

  const targetInvIds: number[] = [];
  const invMap: Record<number, boolean> = {};

  if (stopObj) {
    const invId = stopObj.inventory_id || stopObj.created_inventory_id;
    if (invId && !invMap[invId]) {
      invMap[invId] = true;
      targetInvIds.push(invId);
    }
    if (stopObj.shared_inventory_master) {
      const masterRes = remote.call(csInterface, 'query', {
        type: 'stops',
        ids: [stopObj.shared_inventory_master],
      }) as any;
      if (masterRes && masterRes.data) {
        for (const m of masterRes.data) {
          const mInvId = m && (m.inventory_id || m.created_inventory_id);
          if (mInvId && !invMap[mInvId]) {
            invMap[mInvId] = true;
            targetInvIds.push(mInvId);
          }
        }
      }
    }
  }

  strace.trace(
    modPrefix,
    'find_station_success',
    'combinator',
    entity.unit_number,
    'stop_unit',
    stopUnit,
    'inventories',
    targetInvIds.length,
  );

  return $multi(stopUnit, targetInvIds);
}

let cachedAllInvData: any[] | undefined = undefined;
let cachedAllInvTick = 0;

function getAllWorldInventories(csInterface: string): any[] | undefined {
  const currentTick = typeof game !== 'undefined' && game ? game.tick : 0;
  if (cachedAllInvData !== undefined && currentTick - cachedAllInvTick < 60) {
    return cachedAllInvData;
  }

  const stopsRes = remote.call(csInterface, 'query', { type: 'stops', all: true }) as any;
  if (!stopsRes || !stopsRes.data) {
    return undefined;
  }

  const invIds: number[] = [];
  const invSeen: Record<number, boolean> = {};
  for (const stop of stopsRes.data) {
    const invId = stop.inventory_id || stop.created_inventory_id;
    if (invId && !invSeen[invId]) {
      invSeen[invId] = true;
      invIds.push(invId);
    }
  }

  if (invIds.length === 0) return undefined;

  const allInvRes = remote.call(csInterface, 'query', {
    type: 'inventories',
    ids: invIds,
  }) as any;

  if (allInvRes && allInvRes.data) {
    cachedAllInvData = allInvRes.data;
    cachedAllInvTick = currentTick;
    return cachedAllInvData;
  }

  return undefined;
}

/**
 * Queries Cybersyn 2 for global priorities and demand/supply statistics for unique signals.
 */
export function querySignalPriorities(
  entity: LuaEntity,
  cachedInvIds?: number[],
): SignalPriorityStat[] {
  const csInterface = getCybersynInterface();
  if (!entity || !entity.valid || !csInterface) {
    strace.trace(modPrefix, 'query_skip', 'valid', entity?.valid, 'csInterface', csInterface);
    return [];
  }

  // STEP 1: Locate target Cybersyn 2 station inventories first (early exit if no station)
  let targetInvIds = cachedInvIds;
  if (!targetInvIds || targetInvIds.length === 0) {
    const [_, resolvedInvIds] = findStationForCombinator(entity);
    targetInvIds = resolvedInvIds;
  }

  if (!targetInvIds || targetInvIds.length === 0) {
    strace.trace(modPrefix, 'no_station_inventories', 'combinator', entity.unit_number);
    return [];
  }

  const invRes = remote.call(csInterface, 'query', {
    type: 'inventories',
    ids: targetInvIds,
  }) as any;

  if (!invRes || !invRes.data || invRes.data.length === 0) {
    strace.trace(modPrefix, 'no_inventory_data', 'combinator', entity.unit_number);
    return [];
  }

  // STEP 2: Collect unique item/fluid signals from station orders/inventory
  const uniqueSignalsMap: Record<string, SignalID> = {};
  const uniqueSignalsList: SignalID[] = [];

  const addSignalsFromDict = (dict: any) => {
    if (!dict || typeof dict !== 'object') return;
    for (const [k] of pairs(dict as Record<string, number>)) {
      const parsed = parseSignalKey(k as string);
      if (parsed && parsed.name && !uniqueSignalsMap[parsed.name]) {
        uniqueSignalsMap[parsed.name] = parsed;
        uniqueSignalsList.push(parsed);
      }
    }
  };

  for (const inv of invRes.data) {
    addSignalsFromDict(inv.inventory);
    addSignalsFromDict(inv.inflow);
    addSignalsFromDict(inv.outflow);

    if (inv.orders) {
      for (const orderObj of inv.orders) {
        addSignalsFromDict(orderObj.provides);
        addSignalsFromDict(orderObj.requests);
        addSignalsFromDict(orderObj.requested_fluids);
      }
    }
  }

  // Also include signals configured in the combinator's custom sections
  const comb = new Combinator(entity);
  const cb = comb.getControlBehavior();
  if (cb && cb.valid) {
    const totalSections = cb.sections_count;
    for (let secIdx = 3; secIdx <= totalSections; secIdx++) {
      const sec = cb.get_section(secIdx);
      if (sec && sec.valid) {
        const filters = sec.filters;
        if (filters !== undefined) {
          for (const f of filters) {
            if (f && f.value) {
              const val = f.value;
              const sName = typeof val === 'string' ? val : val.name;
              const sType = typeof val === 'string' ? 'item' : val.type || 'item';
              const sQuality = typeof val === 'object' ? val.quality : undefined;
              if (sName && !uniqueSignalsMap[sName]) {
                const sig: SignalID = { type: sType as any, name: sName, quality: sQuality };
                uniqueSignalsMap[sName] = sig;
                uniqueSignalsList.push(sig);
              }
            }
          }
        }
      }
    }
  }

  strace.trace(
    modPrefix,
    'station_signals',
    'combinator',
    entity.unit_number,
    'signals_found',
    uniqueSignalsList.length,
    'inventories',
    targetInvIds.length,
  );

  if (uniqueSignalsList.length === 0) return [];

  // STEP 3: Retrieve network mask of the current combinator
  const currentNetSig = comb.getNetworkSignal();
  const currentNetCount = currentNetSig?.count;
  const currentNetName = currentNetSig?.signal?.name;

  const isNetworkMatched = (orderObj: any, inv: any): boolean => {
    if (!currentNetSig || !currentNetSig.signal) return true;
    const targetNet =
      orderObj.network ||
      orderObj.network_mask ||
      orderObj.network_id ||
      orderObj.network_flag ||
      (inv && (inv.network || inv.network_mask || inv.network_id || inv.network_flag));

    if (!targetNet) return true;

    if (
      typeof targetNet === 'number' &&
      typeof currentNetCount === 'number' &&
      currentNetCount !== 0
    ) {
      return (targetNet & currentNetCount) !== 0;
    } else if (typeof targetNet === 'string' && currentNetName) {
      return targetNet === currentNetName || (targetNet as string).indexOf(currentNetName) !== -1;
    }

    return true;
  };

  // STEP 4: Initialize structured priority stats container for each signal
  const signalStats: Record<string, SignalPriorityStat> = {};
  for (const sig of uniqueSignalsList) {
    if (sig.name) {
      signalStats[sig.name] = {
        signal: sig,
        reqFound: false,
        supFound: false,
      };
    }
  }

  // STEP 5: Query all Cybersyn orders in the world and compute Min/Max priorities
  const allInventories = getAllWorldInventories(csInterface);
  if (allInventories && allInventories.length > 0) {
    const processOrderDict = (dict: any, isRequest: boolean, prio: number) => {
      if (!dict || typeof dict !== 'object') return;
      for (const [k] of pairs(dict as Record<string, number>)) {
        const keyStr = k as string;
        let stat = signalStats[keyStr];
        if (stat === undefined) {
          const pipeIdx = keyStr.indexOf('|');
          if (pipeIdx !== -1) {
            stat = signalStats[keyStr.substring(0, pipeIdx)];
          }
        }

        if (stat !== undefined) {
          if (isRequest) {
            stat.reqFound = true;
            if (stat.reqMax === undefined || prio > stat.reqMax) stat.reqMax = prio;
            if (stat.reqMin === undefined || prio < stat.reqMin) stat.reqMin = prio;
          } else {
            stat.supFound = true;
            if (stat.supMax === undefined || prio > stat.supMax) stat.supMax = prio;
            if (stat.supMin === undefined || prio < stat.supMin) stat.supMin = prio;
          }
        }
      }
    };

    for (const inv of allInventories) {
      if (inv.orders) {
        for (const orderObj of inv.orders) {
          if (isNetworkMatched(orderObj, inv)) {
            const prio = tonumber(orderObj.priority) || 0;
            processOrderDict(orderObj.requests, true, prio);
            processOrderDict(orderObj.requested_fluids, true, prio);
            processOrderDict(orderObj.provides, false, prio);
          }
        }
      }
    }
  }

  // STEP 6: Build final array of priority statistics for GUI rendering
  const resultList: SignalPriorityStat[] = [];
  for (const sig of uniqueSignalsList) {
    if (sig.name && signalStats[sig.name]) {
      resultList.push(signalStats[sig.name]);
    }
  }

  strace.trace(
    modPrefix,
    'query_result',
    'combinator',
    entity.unit_number,
    'stats_count',
    resultList.length,
  );

  return resultList;
}
