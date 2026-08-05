local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"

local Pr = relm.Primitive
local VF = ultros.VFlow

---@class C2CC.SectionGroupData
---@field public section_index integer Group section index in control behavior.
---@field public group_name string Formatted display group name.
---@field public raw_group_name string Raw unformatted group name string.
---@field public is_active boolean Whether section is enabled/active.
---@field public max_slot_found integer Highest non-empty slot index.
---@field public slots table<integer, { signal: SignalID, count: integer }> Slot filters data map.

---@class C2CC.SectionGroupProps : Relm.Props
---@field public grp C2CC.SectionGroupData Section group data object.
---@field public groups_count integer Total count of groups in combinator.
---@field public selected_section? integer Currently selected group section index.
---@field public selected_slot? integer Currently selected slot index in group.
---@field public combinator? C2CC Combinator wrapper instance.
---@field public edit_items_text? string Current items count input text.
---@field public edit_stacks_text? string Current stacks input text.
---@field public sign? integer 1 or -1 sign multiplier.
---@field public player_index? integer Player index.
---@field public on_select_slot? fun(sec_idx: integer, slot_idx: integer) Callback when a slot is clicked to select.
---@field public set_groups? fun(groups: C2CC.SectionGroupData[]) Setter for reactive groups state.
---@field public on_reset_selection? fun() Reset selection callback.

relm.define_element({
  name = "C2CC.SectionGroup",
  render = function(props)
    ---@cast props C2CC.SectionGroupProps
    -- Encapsulated local editing state for each group section
    local is_editing, set_is_editing = relm.use_state(false)
    local rename_text, set_rename_text = relm.use_state("")

    local grp = props.grp
    local selected_section = props.selected_section
    local selected_slot = props.selected_slot
    local combinator = props.combinator
    local edit_items_text = props.edit_items_text or ""
    local edit_stacks_text = props.edit_stacks_text or ""
    local sign = props.sign or 1
    local player_index = props.player_index

    local on_select_slot = props.on_select_slot
    local set_groups = props.set_groups
    local on_reset_selection = props.on_reset_selection

    local function handle_confirm(new_name)
      local final_name = new_name or rename_text
      if combinator then
        combinator:rename_group(grp.section_index, final_name)
      end
      set_is_editing(false)
      set_rename_text("")
      if set_groups and combinator then set_groups(combinator:get_groups()) end
    end

    local function handle_cancel()
      set_is_editing(false)
      set_rename_text("")
    end

    local slot_buttons = {}
    local max_filled = grp.max_slot_found or 0
    local num_rows = math.ceil((max_filled + 1) / 10)
    if num_rows < 1 then num_rows = 1 end
    local total_display_slots = num_rows * 10

    for slot_idx = 1, total_display_slots do
      local sdata = grp.slots[slot_idx]
      local is_selected = (selected_section == grp.section_index and selected_slot == slot_idx)

      if sdata and sdata.signal then
        slot_buttons[#slot_buttons + 1] = Pr({
          type = "choose-elem-button",
          elem_type = "signal",
          elem_value = sdata.signal,
          style = is_selected and "relm_selected_slot_button_default" or "relm_slot_button_default",
          locked = true,
          enabled = grp.is_active,
          listen = grp.is_active,
          message_handler = ultros.handle_gui_events(
            defines.events.on_gui_click,
            function(_, gui_event)
              if not grp.is_active then return end
              if gui_event.button == defines.mouse_button_type.right then
                if combinator then
                  combinator:remove_group_slot(grp.section_index, slot_idx)
                  if set_groups then set_groups(combinator:get_groups()) end
                end
              else
                if on_select_slot then on_select_slot(grp.section_index, slot_idx) end
              end
            end
          )
        }, {
          sdata.count ~= 0 and Pr({
            type = "label",
            style = "relm_label_signal_count",
            caption = utils.format_short_number(sdata.count),
            ignored_by_interaction = true
          }) or nil
        })
      else
        slot_buttons[#slot_buttons + 1] = ultros.ChooseElemButton({
          value = nil,
          style = "relm_slot_button_default",
          locked = not grp.is_active,
          enabled = grp.is_active,
          on_change = function(_, new_sig, elem)
            if not grp.is_active then return end
            if new_sig and new_sig.name then
              for i, slot in pairs(grp.slots) do
                if i ~= slot_idx and slot and slot.signal and slot.signal.name == new_sig.name then
                  if elem and elem.valid then
                    elem.elem_value = nil
                  end
                  return
                end
              end

              local is_stackable = utils.is_stackable_signal(new_sig)
              local default_stks = utils.get_default_stacks(player_index)
              local eff_stacks = (edit_stacks_text and edit_stacks_text ~= "") and edit_stacks_text or default_stks
              local count = utils.compute_final_count(edit_items_text, eff_stacks, new_sig, sign, is_stackable, default_stks)

              if combinator then
                combinator:set_group_slot(grp.section_index, slot_idx, new_sig, count)
              end
              if on_select_slot then on_select_slot(grp.section_index, slot_idx) end
              if set_groups and combinator then set_groups(combinator:get_groups()) end
            else
              if combinator then
                combinator:remove_group_slot(grp.section_index, slot_idx)
              end
              if set_groups and combinator then set_groups(combinator:get_groups()) end
            end
          end
        })
      end
    end

    local display_caption = grp.group_name
    local max_caption_len = 30
    if #display_caption > max_caption_len then
      display_caption = string.sub(display_caption, 1, max_caption_len - 3) .. "..."
    end

    return VF({
      bottom_margin = 6
    }, {
      Pr({
        type = "frame",
        style = "repeated_subheader_frame",
        direction = "horizontal"
      }, {
        ultros.Checkbox({
          style = "subheader_caption_checkbox",
          caption = display_caption,
          tooltip = #grp.group_name > max_caption_len and grp.group_name or "",
          value = grp.is_active,
          on_change = function()
            local cb = combinator and combinator:get_control_behavior()
            if cb then
              local section = cb.get_section(grp.section_index)
              if section and section.valid then
                section.active = not (section.active ~= false)
              end
            end
            if on_reset_selection then on_reset_selection() end
            if set_groups and combinator then set_groups(combinator:get_groups()) end
          end
        }),
        ultros.SpriteButton({
          sprite = "utility/rename_icon",
          style = "mini_button_aligned_to_text_vertically_when_centered",
          tooltip = "Rename group",
          on_click = function()
            local next_state = not is_editing
            set_is_editing(next_state)
            set_rename_text(next_state and grp.raw_group_name or "")
          end
        }),
        Pr({
          type = "empty-widget",
          horizontally_stretchable = true
        }),
        ultros.SpriteButton({
          sprite = "utility/trash",
          style = "tool_button_red",
          tooltip = "Delete section",
          on_click = function()
            if combinator then
              combinator:remove_group(grp.section_index)
              if on_reset_selection then on_reset_selection() end
              if set_groups and combinator then set_groups(combinator:get_groups()) end
            end
          end
        })
      }),

      is_editing and relm.element("C2CC.GroupEditor", {
        section_index = grp.section_index,
        raw_group_name = grp.raw_group_name,
        rename_text_val = rename_text,
        player_index = player_index,
        on_change_text = set_rename_text,
        on_confirm = function() handle_confirm(nil) end,
        on_cancel = handle_cancel,
        on_select_preset = function(name) handle_confirm(name) end
      }) or nil,

      Pr({ type = "table", column_count = 10, style = "slot_table", top_margin = 4 }, slot_buttons)
    })
  end
})
