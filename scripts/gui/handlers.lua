local utils = require "scripts.gui.utils"
local things_client = require "__0-things__.client.client"

---@class C2CC.GuiHandlers
local handlers = {}

---Toggles the combinator's active working output state.
---@param combinator C2CC The combinator instance.
---@param is_enabled boolean Current working status.
---@param set_is_enabled fun(val: boolean) Setter function for is_enabled state.
function handlers.toggle_enabled(combinator, is_enabled, set_is_enabled)
  local next_val = not is_enabled
  combinator:set_enabled(next_val)
  set_is_enabled(next_val)
end

---Updates the combinator station priority value.
---@param combinator C2CC The combinator instance.
---@param val string|number Priority value text or number.
---@param set_priority fun(val: string|integer) Setter function for priority state.
function handlers.change_priority(combinator, val, set_priority)
  if val == nil or val == "" or val == "-" then
    set_priority(val or "")
    return
  end
  local num_val = utils.to_int32(val)
  combinator:set_priority(num_val)
  set_priority(num_val)
end

---Changes the current network mask signal.
---@param combinator C2CC The combinator instance.
---@param gs table Persistent player GUI state.
---@param sig? SignalID Selected network signal.
---@param cur_net_val integer Current network mask bitmask value.
---@param set_new_mask_signal fun(sig?: SignalID) Setter for mask signal state.
---@param set_groups fun(groups: C2CC.SectionGroupData[]) Setter for groups state.
function handlers.change_new_mask_signal(combinator, gs, sig, cur_net_val, set_new_mask_signal, set_groups)
  if sig and sig.name then
    gs.new_mask_signal = sig
    combinator:set_network_signals({ { signal = sig, count = cur_net_val } })
    set_new_mask_signal(sig)
  else
    combinator:set_network_signals({})
    set_groups(combinator:get_groups())
  end
end

---Changes the current network mask integer value.
---@param combinator C2CC The combinator instance.
---@param gs table Persistent player GUI state.
---@param new_mask_signal? SignalID Active mask signal.
---@param val string|number Bitmask integer value text or number.
---@param set_new_mask_val fun(val: string|integer) Setter for mask value state.
function handlers.change_new_mask_val(combinator, gs, new_mask_signal, val, set_new_mask_val)
  if val == nil or val == "" or val == "-" then
    gs.new_mask_val = val or ""
    set_new_mask_val(val or "")
    return
  end
  local num_val = utils.to_int32(val)
  gs.new_mask_val = num_val
  if new_mask_signal and new_mask_signal.name then
    if num_val ~= 0 then
      combinator:set_network_signals({ { signal = new_mask_signal, count = num_val } })
    else
      combinator:set_network_signals({})
    end
  end
  set_new_mask_val(num_val)
end

---Selects a global network signal and value preset.
---@param combinator C2CC The combinator instance.
---@param gs table Persistent player GUI state.
---@param sig SignalID Network signal ID.
---@param count integer Network bitmask count value.
---@param set_new_mask_signal fun(sig?: SignalID) Setter for mask signal.
---@param set_new_mask_val fun(val: integer) Setter for mask value.
---@param set_networks_open fun(open: boolean) Setter for networks dialog open state.
function handlers.select_global_network(combinator, gs, sig, count, set_new_mask_signal, set_new_mask_val, set_networks_open)
  if sig and sig.name then
    gs.new_mask_signal = sig
    gs.new_mask_val = count
    combinator:set_network_signals({ { signal = sig, count = count } })
    set_new_mask_signal(sig)
    set_new_mask_val(count)
    set_networks_open(false)
  end
end

---Toggles the bitmask encoder dialog visibility.
---@param encoder_open boolean Current open status of encoder.
---@param new_mask_val integer Current active mask value.
---@param set_encoder_open fun(open: boolean) Setter for encoder open state.
---@param set_networks_open fun(open: boolean) Setter for networks dialog open state.
---@param set_encoder_mask fun(mask: integer) Setter for encoder mask state.
function handlers.toggle_encoder(encoder_open, new_mask_val, set_encoder_open, set_networks_open, set_encoder_mask)
  local open = not encoder_open
  set_encoder_open(open)
  set_networks_open(false)
  set_encoder_mask(new_mask_val or utils.get_default_network_flag())
end

---Toggles the global active networks picker dialog visibility.
---@param networks_open boolean Current open status of networks dialog.
---@param set_networks_open fun(open: boolean) Setter for networks open state.
---@param set_encoder_open fun(open: boolean) Setter for encoder open state.
function handlers.toggle_networks(networks_open, set_networks_open, set_encoder_open)
  local open = not networks_open
  set_networks_open(open)
  set_encoder_open(false)
end

---Applies the bitmask encoder mask value to combinator network signals.
---@param combinator C2CC The combinator instance.
---@param gs table Persistent player GUI state.
---@param new_mask_signal? SignalID Active mask signal.
---@param mask_val number|integer Computed bitmask value.
---@param set_encoder_open fun(open: boolean) Setter for encoder open state.
---@param set_new_mask_val fun(val: integer) Setter for network mask value state.
---@param set_encoder_mask fun(mask: integer) Setter for encoder mask state.
function handlers.encoder_apply(combinator, gs, new_mask_signal, mask_val, set_encoder_open, set_new_mask_val, set_encoder_mask)
  local num_val = utils.to_int32(mask_val)
  gs.new_mask_val = num_val
  if new_mask_signal and new_mask_signal.name then
    if num_val ~= 0 then
      combinator:set_network_signals({ { signal = new_mask_signal, count = num_val } })
    else
      combinator:set_network_signals({})
    end
  end
  set_encoder_open(false)
  set_new_mask_val(num_val)
  set_encoder_mask(num_val)
end

---Updates items count input text and calculates final signal slot value.
---@param combinator C2CC The combinator instance.
---@param player_index integer Player index.
---@param selected_section? integer Currently selected group section index.
---@param selected_slot? integer Currently selected slot index.
---@param edit_stacks_text string Current stacks input text.
---@param sign integer 1 or -1 sign.
---@param val string|number New items input text or number.
---@param set_edit_items_text fun(text: string) Setter for edit items text state.
---@param set_groups fun(groups: C2CC.SectionGroupData[]) Setter for groups state.
function handlers.change_edit_items(combinator, player_index, selected_section, selected_slot, edit_stacks_text, sign, val, set_edit_items_text, set_groups)
  local str_val = val and tostring(val) or ""
  local gs = utils.get_gui_state(player_index)
  gs.edit_items_text = str_val

  if selected_section and selected_slot then
    local cb = combinator:get_control_behavior()
    if cb then
      local section = cb.get_section(selected_section)
      if section and section.valid then
        local filter = section.get_slot(selected_slot)
        if filter and filter.value and filter.value.name then
          local default_stks = utils.get_default_stacks(player_index)
          local count = utils.compute_final_count(str_val, edit_stacks_text, filter.value, sign, false, default_stks)
          combinator:set_group_slot(selected_section, selected_slot, filter.value, count)
        end
      end
    end
  end
  set_edit_items_text(str_val)
  set_groups(combinator:get_groups())
  utils.focus_input_field(player_index, "c2cc_edit_count")
end

---Updates stacks input text and calculates final signal slot value.
---@param combinator C2CC The combinator instance.
---@param player_index integer Player index.
---@param selected_section? integer Currently selected group section index.
---@param selected_slot? integer Currently selected slot index.
---@param edit_items_text string Current items input text.
---@param sign integer 1 or -1 sign.
---@param val string|number New stacks input text or number.
---@param set_edit_stacks_text fun(text: string) Setter for edit stacks text state.
---@param set_groups fun(groups: C2CC.SectionGroupData[]) Setter for groups state.
function handlers.change_edit_stacks(combinator, player_index, selected_section, selected_slot, edit_items_text, sign, val, set_edit_stacks_text, set_groups)
  local str_val = val and tostring(val) or ""
  local gs = utils.get_gui_state(player_index)

  if selected_section and selected_slot then
    local cb = combinator:get_control_behavior()
    if cb then
      local section = cb.get_section(selected_section)
      if section and section.valid then
        local filter = section.get_slot(selected_slot)
        if filter and filter.value and filter.value.name then
          if not utils.is_stackable_signal(filter.value) then
            utils.focus_input_field(player_index, "c2cc_edit_count")
            return
          end

          local default_stks = utils.get_default_stacks(player_index)
          local count = utils.compute_final_count(edit_items_text, str_val, filter.value, sign, true, default_stks)
          combinator:set_group_slot(selected_section, selected_slot, filter.value, count)
        end
      end
    end
  end

  gs.edit_stacks_text = str_val
  set_edit_stacks_text(str_val)
  set_groups(combinator:get_groups())
  utils.focus_input_field(player_index, "c2cc_edit_stacks")
end

---Adds a new group section to the combinator.
---@param combinator C2CC The combinator instance.
---@param set_groups fun(groups: C2CC.SectionGroupData[]) Setter for groups state.
function handlers.add_group(combinator, set_groups)
  combinator:add_group("")
  set_groups(combinator:get_groups())
end

---Removes a group section from the combinator.
---@param combinator C2CC The combinator instance.
---@param player_index integer Player index.
---@param sec_idx integer Section index to remove.
---@param set_selected_section fun(sec?: integer) Setter for selected section.
---@param set_selected_slot fun(slot?: integer) Setter for selected slot.
---@param set_groups fun(groups: C2CC.SectionGroupData[]) Setter for groups state.
function handlers.remove_group(combinator, player_index, sec_idx, set_selected_section, set_selected_slot, set_groups)
  local gs = utils.get_gui_state(player_index)
  combinator:remove_group(sec_idx)
  gs.selected_section = nil
  gs.selected_slot = nil
  set_selected_section(nil)
  set_selected_slot(nil)
  set_groups(combinator:get_groups())
end

---Toggles a group section active status.
---@param entity LuaEntity Combinator entity.
---@param sec_idx integer Section index to toggle.
---@param set_groups fun(groups: C2CC.SectionGroupData[]) Setter for groups state.
---@param combinator C2CC The combinator instance.
function handlers.toggle_group_active(entity, sec_idx, set_groups, combinator)
  local cb = entity.get_control_behavior()
  if cb then
    local section = cb.get_section(sec_idx)
    if section and section.valid then
      section.active = not (section.active ~= false)
    end
  end
  set_groups(combinator:get_groups())
end

---Handles clicking a signal slot in a section group to select it.
---@param combinator C2CC The combinator instance.
---@param player_index integer Player index.
---@param sign integer 1 or -1 sign multiplier.
---@param sec_idx integer Section index.
---@param slot_idx integer Slot index.
---@param set_edit_items_text fun(text: string) Setter for edit items text.
---@param set_edit_stacks_text fun(text: string) Setter for edit stacks text.
---@param set_selected_section fun(sec?: integer) Setter for selected section.
---@param set_selected_slot fun(slot?: integer) Setter for selected slot.
---@param set_focus_slot_token? fun(token?: string) Setter for focus slot token.
function handlers.group_slot_clicked(combinator, player_index, sign, sec_idx, slot_idx, set_edit_items_text, set_edit_stacks_text, set_selected_section, set_selected_slot, set_focus_slot_token)
  local gs = utils.get_gui_state(player_index)

  local cb = combinator:get_control_behavior()
  if cb then
    local section = cb.get_section(sec_idx)
    if section and section.valid then
      local filter = section.get_slot(slot_idx)
      if filter and filter.value and filter.value.name then
        local raw_count = filter.min or 0
        local display_sign = raw_count < 0 and -1 or 1
        local count = math.abs(raw_count)
        local is_stackable = utils.is_stackable_signal(filter.value)
        local s_size = utils.get_stack_size(filter.value)

        local items_str = tostring(display_sign * count)
        set_edit_items_text(items_str)
        gs.edit_items_text = items_str

        if is_stackable then
          local stacks_str = tostring(display_sign * math.ceil(count / s_size))
          set_edit_stacks_text(stacks_str)
          gs.edit_stacks_text = stacks_str
        end

        gs.selected_section = sec_idx
        gs.selected_slot = slot_idx
      end
    end
  end
  gs.selected_section = sec_idx
  gs.selected_slot = slot_idx
  set_selected_section(sec_idx)
  set_selected_slot(slot_idx)
  if set_focus_slot_token then
    set_focus_slot_token(sec_idx .. "_" .. slot_idx .. "_" .. tostring(math.random()))
  end
end

return handlers
