local constants = require "scripts.constants"

local CS_PRIORITY = constants.SETTINGS.CS_PRIORITY_NAME

for _, surface in pairs(game.surfaces) do
  local entities = surface.find_entities_filtered { name = constants.ENTITY_NAME }
  local ghosts = surface.find_entities_filtered { name = "entity-ghost", ghost_name = constants.ENTITY_NAME }

  for _, entity_list in ipairs({ entities, ghosts }) do
    for _, entity in ipairs(entity_list) do
      if entity and entity.valid then
        local cb = entity.get_control_behavior()
        if cb then
          local priority_filter = nil
          local network_filter = nil
          local custom_groups = {}

          for i = 1, cb.sections_count do
            local sec = cb.get_section(i)
            if sec and sec.valid then
              local is_priority_sec = false
              local is_network_sec = false

              local slot1 = sec.get_slot(1)
              if slot1 and slot1.value and slot1.value.name then
                if slot1.value.name == CS_PRIORITY then
                  is_priority_sec = true
                  priority_filter = slot1
                elseif slot1.value.type == "virtual" and (sec.group == "" or not sec.group) then
                  is_network_sec = true
                  network_filter = slot1
                end
              end

              if not is_priority_sec and not is_network_sec then
                local slot_map = {}
                local filters_count = sec.filters_count or 40
                local has_any_filter = false
                for slot_idx = 1, math.max(40, filters_count) do
                  local filter = sec.get_slot(slot_idx)
                  if filter and filter.value and filter.value.name then
                    slot_map[slot_idx] = filter
                    has_any_filter = true
                  end
                end
                if (sec.group and sec.group ~= "") or has_any_filter then
                  table.insert(custom_groups, {
                    group = sec.group or "",
                    active = sec.active ~= false,
                    slots = slot_map
                  })
                end
              end
            end
          end

          -- Clear all existing sections
          for i = cb.sections_count, 1, -1 do
            cb.remove_section(i)
          end

          -- Section 1: Priority
          local s1 = cb.add_section("")
          if priority_filter then
            s1.set_slot(1, priority_filter)
          else
            local def_prio = constants.SETTINGS.DEFAULT_PRIORITY
            if def_prio ~= 0 then
              s1.set_slot(1, {
                value = { type = "virtual", name = CS_PRIORITY, quality = "normal" },
                min = def_prio
              })
            end
          end

          -- Section 2: Network Mask
          local s2 = cb.add_section("")
          if network_filter then
            s2.set_slot(1, network_filter)
          else
            local def_flag = constants.SETTINGS.DEFAULT_NETWORK_FLAG
            local def_sig = constants.SETTINGS.DEFAULT_NETWORK_SIGNAL
            if def_flag ~= 0 then
              s2.set_slot(1, {
                value = { type = def_sig.type or "virtual", name = def_sig.name, quality = "normal" },
                min = def_flag
              })
            end
          end

          -- Section 3+: Custom Groups
          for _, grp in ipairs(custom_groups) do
            local sec = cb.add_section(grp.group or "")
            sec.active = grp.active ~= false
            for slot_idx, filter in pairs(grp.slots) do
              sec.set_slot(slot_idx, filter)
            end
          end

          if cb.sections_count < 3 then
            cb.add_section("")
          end
        end
      end
    end
  end
end
