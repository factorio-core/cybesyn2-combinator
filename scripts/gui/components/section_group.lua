local relm = require "__cybersyn2-combinator__.lib.core.relm.relm"
local ultros = require "__cybersyn2-combinator__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"
local GuiState = require "scripts.models.gui_state"
local constants = require "scripts.constants"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

---@class C2CC.SectionGroupData
---@field public GroupIndex integer Group index in control behavior.
---@field public GroupName string Formatted display group name.
---@field public RawGroupName string Raw unformatted group name string.
---@field public IsActive boolean Whether section is enabled/active.
---@field public MaxSlotFound integer Highest non-empty slot index.
---@field public Slots table<integer, { Signal: SignalID, Count: integer }> Slot filters data map.

---@class C2CC.SectionGroupProps : Relm.Props
---@field public grp C2CC.SectionGroupData Section group data object.
---@field public groups_count integer Total count of groups in combinator.
---@field public selected_section? integer Currently selected group section index.
---@field public selected_slot? integer Currently selected slot index in group.
---@field public combinator? C2CC Combinator wrapper instance.
---@field public sign? integer 1 or -1 sign multiplier.
---@field public player_index? integer Player index.
---@field public on_select_slot? fun(sec_idx: integer, slot_idx: integer) Callback when a slot is clicked to select.
---@field public update? fun() Update callback to trigger UI re-render.
---@field public on_reset_selection? fun() Reset selection callback.

local C = constants.CAPTIONS

relm.define_element({
  name = constants.GUI.SECTION_GROUP_ELEMENT_NAME,
  render = function(props)
    -- Encapsulated local editing state for each group section
    local is_editing, set_is_editing = relm.use_state(false)
    local rename_text, set_rename_text = relm.use_state("")
    local preset_items, set_preset_items = relm.use_state({})

    -- Scanned ONCE when group editing frame opens (is_editing transitions to true)
    relm.use_effect(is_editing, function()
      if is_editing then
        local group_map = utils.get_all_global_groups()
        local names = {}
        for name in pairs(group_map) do
          table.insert(names, name)
        end
        table.sort(names)

        local items = { "Select a preset..." }
        for _, name in ipairs(names) do
          table.insert(items, name)
        end
        set_preset_items(items)
      else
        set_preset_items({})
      end
    end)

    local grp = props.grp
    local selected_section = props.selected_section
    local selected_slot = props.selected_slot
    local combinator = props.combinator
    local player_index = props.player_index
    local gs = GuiState.Get(player_index)

    local on_select_slot = props.on_select_slot
    local update = props.update
    local on_reset_selection = props.on_reset_selection

    local function handle_confirm(new_name, slots)
      local final_name = new_name or rename_text
      if combinator then
        local target_slots = slots
        if not target_slots and final_name ~= "" then
          local global_groups = utils.get_all_global_groups()
          target_slots = global_groups[final_name]
        end
        combinator:RenameGroup(grp.GroupIndex, final_name)
        if target_slots and type(target_slots) == "table" and next(target_slots) then
          combinator:SetGroupSlotsBulk(grp.GroupIndex, target_slots)
        end
      end
      set_is_editing(false)
      set_rename_text("")
      if update then update() end
    end

    local function handle_cancel()
      set_is_editing(false)
      set_rename_text("")
    end

    local gs = GuiState.Get(player_index)

    local dropdown_items = preset_items

    local slot_buttons = {}
    local max_filled = grp.MaxSlotFound or 0
    local num_rows = math.ceil((max_filled + 1) / 10)
    if num_rows < 1 then num_rows = 1 end
    local total_display_slots = num_rows * 10

    for slot_idx = 1, total_display_slots do
      local sdata = grp.Slots[slot_idx]
      local is_selected = (selected_section == grp.GroupIndex and selected_slot == slot_idx)

      if sdata and sdata.Signal then
        slot_buttons[#slot_buttons + 1] = Pr({
          type = "choose-elem-button",
          elem_type = "signal",
          elem_value = sdata.Signal,
          style = is_selected and "relm_selected_slot_button_default" or "relm_slot_button_default",
          locked = true,
          enabled = grp.IsActive,
          listen = grp.IsActive,
          message_handler = ultros.handle_gui_events(
            defines.events.on_gui_click,
            function(_, gui_event)
              if not grp.IsActive then return end
              if gui_event.button == defines.mouse_button_type.right then
                if combinator then
                  combinator:RemoveGroupSlot(grp.GroupIndex, slot_idx)
                  if on_reset_selection then on_reset_selection() end
                  if update then update() end
                end
              else
                if on_select_slot then on_select_slot(grp.GroupIndex, slot_idx) end
              end
            end
          )
        }, {
          sdata.Count ~= 0 and Pr({
            type = "label",
            style = "relm_label_signal_count",
            caption = utils.format_short_number(sdata.Count),
            ignored_by_interaction = true
          }) or nil
        })
      else
        slot_buttons[#slot_buttons + 1] = ultros.ChooseElemButton({
          value = nil,
          style = "relm_slot_button_default",
          locked = not grp.IsActive,
          enabled = grp.IsActive,
          on_change = function(_, new_sig, elem)
            if not grp.IsActive then return end
            if new_sig and new_sig.name then
              for i, slot in pairs(grp.Slots) do
                if i ~= slot_idx and slot and slot.Signal and slot.Signal.name == new_sig.name then
                  if elem and elem.valid then
                    elem.elem_value = nil
                  end
                  return
                end
              end

              local count = gs:CalculateInitialSignalCount(new_sig)

              if combinator then
                combinator:SetGroupSlot(grp.GroupIndex, slot_idx, new_sig, count)
              end
              if on_select_slot then on_select_slot(grp.GroupIndex, slot_idx) end
              if update then update() end
            else
              if combinator then
                combinator:RemoveGroupSlot(grp.GroupIndex, slot_idx)
              end
              if update then update() end
            end
          end
        })
      end
    end

    local display_caption = grp.GroupName
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
          tooltip = #grp.GroupName > max_caption_len and grp.GroupName or "",
          value = grp.IsActive,
          on_change = function(_, state)
            gs:SetGroupActive(grp.GroupIndex, state)
            if on_reset_selection then on_reset_selection() end
            if update then update() end
          end
        }),
        ultros.SpriteButton({
          sprite = "utility/rename_icon",
          style = "mini_button_aligned_to_text_vertically_when_centered",
          tooltip = "Rename group",
          on_click = function()
            local next_state = not is_editing
            set_is_editing(next_state)
            set_rename_text(next_state and grp.RawGroupName or "")
            if next_state then
              gs:SetTargetFocusField(constants.GUI.FIELD_RENAME_GROUP_INPUT)
            end
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
            gs:RemoveGroup(grp.GroupIndex)
            if on_reset_selection then on_reset_selection() end
            if update then update() end
          end
        })
      }),

      is_editing and Pr({
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
        top_margin = 4,
        bottom_margin = 6,
        ref = function(elt)
          if elt and elt.valid then
            local parent = elt.parent
            while parent and parent.valid do
              if parent.type == "scroll-pane" then
                parent.scroll_to_element(elt)
                break
              end
              parent = parent.parent
            end
          end
        end
      }, {
        VF({
          ultros.BoldLabel(C.RENAME_GROUP),
          HF({ vertical_align = "center", top_margin = 4 }, {
            ultros.Input({
              name = constants.GUI.FIELD_RENAME_GROUP_INPUT,
              ref = function(elt)
                if elt and elt.valid and gs.GuiMain.TargetFocusField == constants.GUI.FIELD_RENAME_GROUP_INPUT then
                  elt.focus()
                  gs:SetTargetFocusField(nil)
                end
              end,
              text = rename_text ~= "" and rename_text or grp.RawGroupName,
              width = 150,
              on_change = function(_, _, element)
                set_rename_text(element.text)
              end,
              on_confirm = function()
                handle_confirm(nil)
              end
            }),
            ultros.Button({
              caption = C.SAVE,
              style = "confirm_button",
              height = 28,
              on_click = function()
                handle_confirm(nil)
              end
            }),
            ultros.Button({
              caption = C.CANCEL,
              style = "red_button",
              height = 28,
              on_click = handle_cancel
            })
          }),

          #preset_items > 1 and VF({
            top_margin = 6
          }, {
            ultros.BoldLabel(C.EXISTING_GROUPS),
            Pr({
              type = "drop-down",
              items = dropdown_items,
              selected_index = 1,
              listen = true,
              message_handler = ultros.handle_gui_events(
                defines.events.on_gui_selection_state_changed,
                function(me, gui_event)
                  local my_elt = gui_event.element
                  if my_elt and my_elt.valid then
                    local sel_idx = my_elt.selected_index
                    if sel_idx > 1 then
                      local selected_name = dropdown_items[sel_idx]
                      set_rename_text(selected_name)
                      gs:SetTargetFocusField(constants.GUI.FIELD_RENAME_GROUP_INPUT)
                      if update then update() end
                    end
                  end
                end
              )
            })
          }) or nil
        })
      }) or nil,

      Pr({ type = "table", column_count = 10, style = "slot_table", top_margin = 4 }, slot_buttons)
    })
  end
})
