import { parseSignalKey } from './priorities';
import * as sigLib from 'fcore/utils/signal';

export function areNetworksEqual(
  oldList: ActiveNetworkEntry[] | undefined,
  newList: ActiveNetworkEntry[] | undefined,
): boolean {
  if (oldList === newList) return true;
  if (!oldList || !newList) return false;
  if (oldList.length !== newList.length) return false;
  for (let i = 0; i < newList.length; i++) {
    const a = oldList[i];
    const b = newList[i];
    if (!a || !b || !a.signal || !b.signal) return false;
    if (
      a.signal.name !== b.signal.name ||
      a.signal.type !== b.signal.type ||
      a.signal.quality !== b.signal.quality ||
      a.count !== b.count
    ) {
      return false;
    }
  }
  return true;
}

export function getAllGlobalActiveNetworks(): ActiveNetworkEntry[] {
  if (!game || !remote.interfaces['cybersyn2']) return [];

  const uniqueMap: Record<string, ActiveNetworkEntry> = {};

  const processNetworksDict = (dict: any) => {
    if (!dict || typeof dict !== 'object') return;
    for (const [k, count] of pairs(dict as Record<string, number>)) {
      let parsed = parseSignalKey(k as string);
      if (!parsed) {
        const stype = sigLib.getSignalTypeFromName(k as string);
        if (stype) parsed = { type: stype, name: k as string };
      }
      if (parsed && parsed.name) {
        const c = tonumber(count) || 0;
        const key = `${parsed.type || 'item'}_${parsed.name}_${parsed.quality || 'normal'}_${c}`;
        if (!uniqueMap[key]) {
          uniqueMap[key] = { signal: parsed, count: c };
        }
      }
    }
  };

  const processNetworksOnObject = (obj: any) => {
    let net = obj.networks;
    if (!net || typeof net !== 'object' || next(net)[0] === undefined) {
      net = obj.network || obj.network_mask || obj.network_flag || obj.network_id;
    }
    processNetworksDict(net);
  };

  const stopsRes = remote.call('cybersyn2', 'query', { type: 'stops', all: true }) as any;
  if (!stopsRes || !stopsRes.data) return [];

  const invIds: number[] = [];
  for (const stop of stopsRes.data) {
    processNetworksOnObject(stop);
    if (stop.inventory_id) invIds.push(stop.inventory_id);
    if (stop.shared_inventory_master) invIds.push(stop.shared_inventory_master);
  }

  if (invIds.length > 0) {
    const invRes = remote.call('cybersyn2', 'query', { type: 'inventories', ids: invIds }) as any;
    if (invRes && invRes.data) {
      for (const inv of invRes.data) {
        if (inv.orders) {
          for (const orderObj of inv.orders) {
            processNetworksOnObject(orderObj);
          }
        }
      }
    }
  }

  const result: ActiveNetworkEntry[] = [];
  for (const [_, entry] of pairs(uniqueMap)) {
    result.push(entry);
  }
  result.sort((a, b) => {
    const na = a.signal.name || '';
    const nb = b.signal.name || '';
    if (na !== nb) return na < nb ? -1 : 1;
    return (a.count || 0) - (b.count || 0);
  });
  return result;
}
