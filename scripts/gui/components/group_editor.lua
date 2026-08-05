local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

---@class C2CC.GroupEditorProps : Relm.Props
---@field public section_index integer Group section index in control behavior.
---@field public raw_group_name string Current raw group name.
---@field public rename_text_val string Current input text state.
---@field public player_index integer Player index.
---@field public on_change_text fun(text: string) Callback when text changes.
---@field public on_confirm fun() Callback when rename confirmed.
---@field public on_cancel fun() Callback when rename canceled.
---@field public on_select_preset fun(name: string) Callback when preset button clicked.

relm.define_element({
  name = "C2CC.GroupEditor",
  render = function(props)
    ---@cast props C2CC.GroupEditorProps
    local raw_group_name = props.raw_group_name
    local rename_text_val = props.rename_text_val
    local on_change_text = props.on_change_text
    local on_confirm = props.on_confirm
    local on_cancel = props.on_cancel
    local on_select_preset = props.on_select_preset

    local existing_world_groups = utils.get_all_global_group_names()
    local gname_buttons = {}
    local max_caption_len = 30

    for _, gname in ipairs(existing_world_groups) do
      local btn_caption = gname
      if #btn_caption > max_caption_len then
        btn_caption = string.sub(btn_caption, 1, max_caption_len - 3) .. "..."
      end

      gname_buttons[#gname_buttons + 1] = ultros.Button({
        caption = btn_caption,
        tooltip = #gname > max_caption_len and gname or "",
        height = 24,
        on_click = function()
          if on_select_preset then on_select_preset(gname) end
        end
      })
    end

    return Pr({
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
      top_margin = 4,
      bottom_margin = 6,
      ref = function(elt)
        if elt and elt.valid then
          -- Find parent scroll-pane and scroll to this editor
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
        ultros.BoldLabel("Rename Group:"),
        HF({ vertical_align = "center", top_margin = 4 }, {
          ultros.Input({
            name = "c2cc_rename_group_input",
            ref = function(elt)
              if elt and elt.valid then
                elt.focus()
              end
            end,
            text = rename_text_val or raw_group_name,
            width = 150,
            on_change = function(_, text)
              if on_change_text then on_change_text(text) end
            end,
            on_confirm = function()
              if on_confirm then on_confirm() end
            end
          }),
          ultros.Button({
            caption = "Save",
            style = "confirm_button",
            height = 28,
            on_click = function()
              if on_confirm then on_confirm() end
            end
          }),
          ultros.Button({
            caption = "Cancel",
            style = "red_button",
            height = 28,
            on_click = function()
              if on_cancel then on_cancel() end
            end
          })
        }),

        #gname_buttons > 0 and VF({
          top_margin = 6
        }, {
          ultros.BoldLabel("Existing Groups in World:"),
          Pr({
            type = "scroll-pane",
            style = "deep_slots_scroll_pane",
            direction = "vertical",
            vertical_scroll_policy = "auto",
            horizontal_scroll_policy = "never",
            maximal_height = 200
          }, {
            VF({}, gname_buttons)
          })
        }) or nil
      })
    })
  end
})
