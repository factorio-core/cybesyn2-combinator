export {};
import { ENTITY_NAME, SETTINGS } from '../scripts/constants';
import type { LuaConstantCombinatorControlBehavior, LogisticFilter } from 'factorio:runtime';

const CS_PRIORITY = SETTINGS.CS_PRIORITY_NAME;

for (const [_, surface] of pairs(game.surfaces)) {
  const entities = surface.find_entities_filtered({ name: ENTITY_NAME });
  const ghosts = surface.find_entities_filtered({ name: 'entity-ghost', ghost_name: ENTITY_NAME });

  for (const entityList of [entities, ghosts]) {
    for (const entity of entityList) {
      if (entity && entity.valid) {
        const cb = entity.get_control_behavior() as LuaConstantCombinatorControlBehavior;
        if (cb !== undefined) {
          let priorityFilter: LogisticFilter | undefined = undefined;
          let networkFilter: LogisticFilter | undefined = undefined;
          const customGroups: {
            group: string;
            active: boolean;
            slots: Record<number, LogisticFilter>;
          }[] = [];

          for (let i = 1; i <= cb.sections_count; i++) {
            const sec = cb.get_section(i);
            if (sec && sec.valid) {
              let isPrioritySec = false;
              let isNetworkSec = false;

              const slot1 = sec.get_slot(1);
              if (slot1 && slot1.value && (slot1.value as any).name) {
                if ((slot1.value as any).name === CS_PRIORITY) {
                  isPrioritySec = true;
                  priorityFilter = slot1;
                } else if (
                  (slot1.value as any).type === 'virtual' &&
                  (!sec.group || sec.group === '')
                ) {
                  isNetworkSec = true;
                  networkFilter = slot1;
                }
              }

              if (!isPrioritySec && !isNetworkSec) {
                const slotMap: Record<number, LogisticFilter> = {};
                const filtersCount = sec.filters_count || 40;
                let hasAnyFilter = false;
                for (let slotIdx = 1; slotIdx <= Math.max(40, filtersCount); slotIdx++) {
                  const filter = sec.get_slot(slotIdx);
                  if (filter && filter.value && (filter.value as any).name) {
                    slotMap[slotIdx] = filter;
                    hasAnyFilter = true;
                  }
                }
                if ((sec.group && sec.group !== '') || hasAnyFilter) {
                  customGroups.push({
                    group: sec.group || '',
                    active: sec.active !== false,
                    slots: slotMap,
                  });
                }
              }
            }
          }

          // Clear all existing sections
          for (let i = cb.sections_count; i >= 1; i--) {
            cb.remove_section(i);
          }

          // Section 1: Priority
          const s1 = cb.add_section('');
          if (s1) {
            if (priorityFilter) {
              s1.set_slot(1, priorityFilter);
            } else {
              const defPrio = SETTINGS.DEFAULT_PRIORITY;
              if (defPrio !== 0) {
                s1.set_slot(1, {
                  value: { type: 'virtual', name: CS_PRIORITY, quality: 'normal' },
                  min: defPrio,
                });
              }
            }
          }

          // Section 2: Network Mask
          const s2 = cb.add_section('');
          if (s2) {
            if (networkFilter) {
              s2.set_slot(1, networkFilter);
            } else {
              const defFlag = SETTINGS.DEFAULT_NETWORK_FLAG;
              const defSig = SETTINGS.DEFAULT_NETWORK_SIGNAL;
              if (defFlag !== 0) {
                s2.set_slot(1, {
                  value: {
                    type: (defSig.type || 'virtual') as any,
                    name: defSig.name as string,
                    quality: 'normal',
                  },
                  min: defFlag,
                });
              }
            }
          }

          // Section 3+: Custom Groups
          for (const grp of customGroups) {
            const sec = cb.add_section(grp.group || '');
            if (sec) {
              sec.active = grp.active;
              for (const [slotIdx, filter] of pairs(grp.slots)) {
                sec.set_slot(slotIdx as number, filter);
              }
            }
          }

          if (cb.sections_count < 3) {
            cb.add_section('');
          }
        }
      }
    }
  }
}
