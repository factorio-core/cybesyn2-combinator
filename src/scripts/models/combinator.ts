import { SECTIONS, SETTINGS, ENTITY_NAME } from '../constants';
import { PlayerSettings } from './player_settings';
import { strace } from 'fcore/utils/strace';
import type {
  LuaConstantCombinatorControlBehavior,
  LuaLogisticSection,
  SignalID,
  LogisticFilter,
  LuaEntity,
  PlayerIndex,
  UnitNumber,
} from 'factorio:runtime';

export type Priority = number;
export type NetworkMask = number;
export type SectionIndex = number;
export type GroupIndex = number;
export type SlotIndex = number;

export function toInt32(val: any): number {
  if (val === undefined) return 0;
  const n = typeof val === 'number' ? val : tonumber(val as any);
  if (n === undefined || n !== n || n === Infinity || n === -Infinity) {
    return 0;
  }
  if (n > 2147483647) {
    if (n <= 4294967295) {
      return Math.floor(n - 4294967296);
    } else {
      return 2147483647;
    }
  } else if (n < -2147483648) {
    return -2147483648;
  }
  return Math.floor(n);
}

function getOrCreateSection(
  cb: LuaConstantCombinatorControlBehavior,
  sectionIndex: SectionIndex,
): LuaLogisticSection | undefined {
  if (!cb || !cb.valid) return undefined;
  while (cb.sections_count < sectionIndex) {
    cb.add_section('');
  }
  return cb.get_section(sectionIndex);
}

function makeFilter(
  signal: SignalID | undefined,
  count: number | string,
): LogisticFilter | undefined {
  if (!signal || !signal.name) return undefined;
  const minVal = toInt32(count);
  const filter: LogisticFilter = {
    value: {
      type: (signal.type || 'item') as any,
      name: signal.name,
      quality: (signal as any).quality || 'normal',
    },
    min: minVal,
  };
  if ((signal as any).comparator) {
    (filter as any).comparator = (signal as any).comparator;
  }
  return filter;
}

let nextSectionUid = 1;
const entitySectionUids: Record<UnitNumber, number[] | undefined> = {};

export class Combinator {
  public entity?: LuaEntity;

  constructor(entity?: LuaEntity) {
    if (entity && entity.valid) {
      this.entity = entity;
    }
  }

  public getEntity(): LuaEntity | undefined {
    return this.entity && this.entity.valid ? this.entity : undefined;
  }

  public getControlBehavior(): LuaConstantCombinatorControlBehavior | undefined {
    const ent = this.getEntity();
    if (ent && (ent as any).get_control_behavior) {
      return (ent as any).get_control_behavior() as LuaConstantCombinatorControlBehavior;
    }
    return undefined;
  }

  public isEnabled(): boolean {
    const cb = this.getControlBehavior();
    return cb ? cb.enabled : true;
  }

  public setEnabled(enabled: boolean): void {
    const cb = this.getControlBehavior();
    if (cb) {
      cb.enabled = enabled;
    }
  }

  public getPriority(): Priority {
    const cb = this.getControlBehavior();
    if (!cb) return 0;
    const sec = getOrCreateSection(cb, SECTIONS.CYBERSYN_PRIORITY);
    if (!sec) return 0;
    const filter = sec.get_slot(1);
    const val = filter?.value as any;
    if (val && (val.name === SETTINGS.CS_PRIORITY_NAME || val === SETTINGS.CS_PRIORITY_NAME)) {
      return filter.min || 0;
    }
    return 0;
  }

  public setPriority(value: Priority | string): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = getOrCreateSection(cb, SECTIONS.CYBERSYN_PRIORITY);
    if (!sec) return;
    const n = toInt32(value);
    if (n !== 0) {
      sec.set_slot(1, makeFilter({ type: 'virtual', name: SETTINGS.CS_PRIORITY_NAME }, n)!);
    } else {
      sec.clear_slot(1);
    }
  }

  public getNetworkSignal(): NetworkSignal | undefined {
    const cb = this.getControlBehavior();
    if (!cb) return undefined;
    const sec = getOrCreateSection(cb, SECTIONS.NETWORK_MASK);
    if (!sec) return undefined;
    const filter = sec.get_slot(1);
    const val = filter?.value as any;
    if (val && (val.name || typeof val === 'string')) {
      const sig: SignalID = typeof val === 'string' ? { name: val, type: 'item' } : val;
      return { signal: sig, count: filter.min || 0 };
    }
    return undefined;
  }

  public setNetworkSignal(netSig?: NetworkSignal): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = getOrCreateSection(cb, SECTIONS.NETWORK_MASK);
    if (!sec) return;
    if (netSig && netSig.signal) {
      sec.set_slot(1, makeFilter(netSig.signal, netSig.count || 0)!);
    } else {
      sec.clear_slot(1);
    }
  }

  public getGroups(): SectionGroupData[] {
    const cb = this.getControlBehavior();
    if (!cb) return [];
    getOrCreateSection(cb, SECTIONS.CYBERSYN_PRIORITY);
    getOrCreateSection(cb, SECTIONS.NETWORK_MASK);
    const groups: SectionGroupData[] = [];
    const count = cb.sections_count;
    const ent = this.getEntity();
    const unitNumber = ent?.unit_number;

    let uids: number[] | undefined;
    if (unitNumber) {
      uids = entitySectionUids[unitNumber];
      if (!uids) {
        uids = [];
        entitySectionUids[unitNumber] = uids;
      }
    }

    let arrIdx = 0;
    for (let i = 3; i <= count; i++) {
      const sec = cb.get_section(i);
      if (sec && sec.valid) {
        let uid = uids && arrIdx < uids.length ? uids[arrIdx] : undefined;
        if (uid === undefined && uids) {
          uid = nextSectionUid++;
          uids.push(uid);
        }
        arrIdx++;

        const slotMap: Record<SlotIndex, SectionGroupSlot | undefined> = {};
        let maxSlot = 0;
        const filtersCount = sec.filters_count || 40;
        for (let slotIdx = 1; slotIdx <= Math.max(40, filtersCount); slotIdx++) {
          const filter = sec.get_slot(slotIdx);
          const val = filter?.value as any;
          if (val && (val.name || typeof val === 'string')) {
            const sig: SignalID = typeof val === 'string' ? { name: val, type: 'item' } : val;
            slotMap[slotIdx] = {
              signal: sig,
              count: filter.min || 0,
            };
            if (slotIdx > maxSlot) maxSlot = slotIdx;
          }
        }

        const rawName = sec.group || '';
        groups.push({
          uid: uid,
          groupIndex: i,
          groupName: rawName || `Group ${i - 2}`,
          rawGroupName: rawName,
          isActive: sec.active !== false,
          maxSlotFound: maxSlot,
          slots: slotMap,
        });
      }
    }

    return groups;
  }

  public getGroupSlot(
    groupIndex: GroupIndex,
    slotIndex: SlotIndex,
  ): LuaMultiReturn<[SignalID | undefined, number]> {
    const cb = this.getControlBehavior();
    if (!cb) return $multi(undefined, 0);
    const sec = cb.get_section(groupIndex);
    if (!sec || !sec.valid) return $multi(undefined, 0);
    const filter = sec.get_slot(slotIndex);
    const val = filter?.value as any;
    if (val && (val.name || typeof val === 'string')) {
      const sig: SignalID = typeof val === 'string' ? { name: val, type: 'item' } : val;
      return $multi(sig, filter.min || 0);
    }
    return $multi(undefined, 0);
  }

  public addGroup(groupName?: string): LuaLogisticSection | undefined {
    const cb = this.getControlBehavior();
    if (!cb) return undefined;
    getOrCreateSection(cb, SECTIONS.CYBERSYN_PRIORITY);
    getOrCreateSection(cb, SECTIONS.NETWORK_MASK);
    const ent = this.getEntity();
    const unitNumber = ent?.unit_number;
    if (!unitNumber) return undefined;

    let uids = entitySectionUids[unitNumber];
    if (!uids) {
      uids = [];
      entitySectionUids[unitNumber] = uids;
    }
    uids.push(nextSectionUid++);
    return cb.add_section(groupName || '');
  }

  public renameGroup(groupIndex: GroupIndex, groupName?: string): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = cb.get_section(groupIndex);
    if (sec && sec.valid) {
      sec.group = groupName || '';
    }
  }

  public removeGroup(groupIndex: GroupIndex): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const ent = this.getEntity();
    const unitNumber = ent?.unit_number;
    if (!unitNumber) return;

    const uids = entitySectionUids[unitNumber];
    if (uids && groupIndex >= 3) {
      const arrIdx = groupIndex - 3;
      if (arrIdx < uids.length) {
        uids.splice(arrIdx, 1);
      }
    }
    cb.remove_section(groupIndex);
  }

  public setGroupActive(groupIndex: GroupIndex, isActive: boolean): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = cb.get_section(groupIndex);
    if (sec && sec.valid) {
      sec.active = isActive !== false;
    }
  }

  public setGroupSlot(
    groupIndex: GroupIndex,
    slotIndex: SlotIndex,
    signal?: SignalID,
    count: number | string = 0,
  ): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = cb.get_section(groupIndex);
    if (!sec || !sec.valid) return;
    const filter = makeFilter(signal, count);
    if (filter) {
      sec.set_slot(slotIndex, filter);
    } else {
      sec.clear_slot(slotIndex);
    }
  }

  public setGroupSlotsBulk(groupIndex: GroupIndex, slots: Record<SlotIndex | string, any>): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = cb.get_section(groupIndex);
    if (!sec || !sec.valid) return;
    const filtersCount = sec.filters_count || 40;
    for (let i = 1; i <= Math.max(40, filtersCount); i++) {
      sec.clear_slot(i);
    }
    for (const [k, v] of pairs(slots || {})) {
      const sIdx = tonumber(k);
      if (sIdx && v) {
        const sig = v.signal || v.Signal;
        const cnt = v.count || v.Count;
        const filter = makeFilter(sig, cnt);
        if (filter) {
          sec.set_slot(sIdx, filter);
        }
      }
    }
  }

  public removeGroupSlot(groupIndex: GroupIndex, slotIndex: SlotIndex): void {
    const cb = this.getControlBehavior();
    if (!cb) return;
    const sec = cb.get_section(groupIndex);
    if (sec && sec.valid) {
      sec.clear_slot(slotIndex);
    }
  }

  public copyFrom(srcComb: Combinator): void {
    if (!srcComb) return;
    const destCb = this.getControlBehavior();
    const srcCb = srcComb.getControlBehavior();
    if (!destCb || !srcCb) return;

    this.setPriority(srcComb.getPriority());
    this.setNetworkSignal(srcComb.getNetworkSignal());

    getOrCreateSection(destCb, SECTIONS.CYBERSYN_PRIORITY);
    getOrCreateSection(destCb, SECTIONS.NETWORK_MASK);

    for (let secIdx = destCb.sections_count; secIdx >= 3; secIdx--) {
      destCb.remove_section(secIdx);
    }

    const srcGroups = srcComb.getGroups();
    for (const grp of srcGroups) {
      const newSec = this.addGroup(grp.rawGroupName);
      if (newSec && newSec.valid) {
        newSec.active = grp.isActive;
        for (const [slotIdx, sdata] of pairs(grp.slots)) {
          if (sdata !== undefined && sdata.signal !== undefined) {
            this.setGroupSlot(newSec.index, tonumber(slotIdx) || 1, sdata.signal, sdata.count);
          }
        }
      }
    }
  }

  public initializeDefaults(fromBlueprint: boolean, playerIndex?: PlayerIndex): void {
    if (fromBlueprint) return;
    const cb = this.getControlBehavior();
    if (!cb) return;

    const ps = PlayerSettings.get((playerIndex || 1) as PlayerIndex);
    const defaultPriority = ps.priority;
    const defaultNetworkFlag = ps.networkFlag;
    const defaultNetworkSignal = ps.defaultNetworkSignal;

    const s1 = getOrCreateSection(cb, SECTIONS.CYBERSYN_PRIORITY);
    const s2 = getOrCreateSection(cb, SECTIONS.NETWORK_MASK);

    if (defaultPriority !== 0 && s1 && !s1.get_slot(1).value) {
      secSlotSet(
        s1,
        1,
        makeFilter({ type: 'virtual', name: SETTINGS.CS_PRIORITY_NAME }, defaultPriority)!,
      );
    }

    if (defaultNetworkFlag !== 0 && s2 && !s2.get_slot(1).value) {
      secSlotSet(s2, 1, makeFilter(defaultNetworkSignal, defaultNetworkFlag)!);
    }

    if (cb.sections_count < 3) {
      cb.add_section('');
    }
  }

  public fixPastedVanillaSections(playerIndex?: PlayerIndex): void {
    const cb = this.getControlBehavior();
    if (!cb) return;

    const savedSections: {
      groupName: string;
      active: boolean;
      filters: Record<number, LogisticFilter>;
    }[] = [];
    for (let i = 1; i <= cb.sections_count; i++) {
      const sec = cb.sections[i - 1];
      if (sec && sec.valid) {
        const filters: Record<number, LogisticFilter> = {};
        for (let slotIdx = 1; slotIdx <= sec.filters_count; slotIdx++) {
          const flt = sec.get_slot(slotIdx);
          if (flt && flt.value) {
            filters[slotIdx] = {
              value: flt.value,
              min: flt.min,
            };
          }
        }
        savedSections.push({
          groupName: sec.group || '',
          active: sec.active,
          filters: filters,
        });
      }
    }

    for (let i = cb.sections_count; i >= 1; i--) {
      cb.remove_section(i);
    }

    this.initializeDefaults(false, playerIndex);

    for (let i = 0; i < savedSections.length; i++) {
      const saved = savedSections[i];
      let targetSec: LuaLogisticSection | undefined;
      if (i === 0 && cb.sections_count >= 3) {
        targetSec = cb.sections[2];
        targetSec.group = saved.groupName;
      } else {
        targetSec = cb.add_section(saved.groupName);
      }

      if (targetSec && targetSec.valid) {
        targetSec.active = saved.active;
        for (const [slotIdx, flt] of pairs(saved.filters)) {
          targetSec.set_slot(tonumber(slotIdx) || 1, {
            value: flt.value,
            min: flt.min,
          });
        }
      }
    }
  }

  public static applyPriorityToAll(oldPriority: number, newPriority: number): number {
    if (!game) return 0;
    const oldPrio = tonumber(oldPriority) || 0;
    const newPrio = tonumber(newPriority) || 0;
    if (oldPrio === newPrio) return 0;

    let count = 0;
    for (const [_, surface] of pairs(game.surfaces)) {
      if (surface && surface.valid) {
        const combinators = surface.find_entities_filtered({ name: ENTITY_NAME });
        for (const entity of combinators) {
          if (entity && entity.valid) {
            const comb = new Combinator(entity);
            if (comb.getPriority() === oldPrio) {
              comb.setPriority(newPrio);
              count++;
            }
          }
        }
      }
    }
    return count;
  }

  public static applyNetworkToAll(
    oldNetworkSignal: SignalID | undefined,
    oldNetworkFlag: number | string,
    newNetworkSignal: SignalID | undefined,
    newNetworkFlag: number | string,
  ): number {
    if (!game) return 0;
    const oldFlag = tonumber(oldNetworkFlag) || 0;
    const newFlag = tonumber(newNetworkFlag) || 0;
    const sameSignal =
      oldNetworkSignal?.name === newNetworkSignal?.name &&
      (oldNetworkSignal?.type || 'item') === (newNetworkSignal?.type || 'item');
    if (sameSignal && oldFlag === newFlag) return 0;

    let count = 0;
    for (const [_, surface] of pairs(game.surfaces)) {
      if (surface && surface.valid) {
        const combinators = surface.find_entities_filtered({ name: ENTITY_NAME });
        for (const entity of combinators) {
          if (entity && entity.valid) {
            const comb = new Combinator(entity);
            const currentNet = comb.getNetworkSignal();
            let matchesOld = false;
            if (currentNet && currentNet.signal && oldNetworkSignal && oldNetworkSignal.name) {
              const sameType =
                (currentNet.signal.type || 'item') === (oldNetworkSignal.type || 'item');
              if (
                sameType &&
                currentNet.signal.name === oldNetworkSignal.name &&
                (tonumber(currentNet.count) || 0) === oldFlag
              ) {
                matchesOld = true;
              }
            }

            if (matchesOld) {
              if (newNetworkSignal && newNetworkSignal.name && newFlag !== 0) {
                comb.setNetworkSignal({ signal: newNetworkSignal, count: newFlag });
              } else {
                comb.setNetworkSignal(undefined);
              }
              count++;
            }
          }
        }
      }
    }
    return count;
  }
}

function secSlotSet(sec: LuaLogisticSection, slot: SlotIndex, filter: LogisticFilter) {
  sec.set_slot(slot, filter);
}

export const C2CC = Combinator;
