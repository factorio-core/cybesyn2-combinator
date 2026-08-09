local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"
local constants = require "scripts.constants"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

local CAPTION_ENCODER_ALL = { "cybersyn2-constant-combinator-encoder.all" }
local CAPTION_ENCODER_NONE = { "cybersyn2-constant-combinator-encoder.none" }

---@class C2CC.EncoderDialogProps : Relm.Props
---@field public mask? integer Current bitmask value.
---@field public on_change_mask? fun(mask: integer) Callback when bitmask changes in encoder.
---@field public on_apply? fun(mask: integer) Callback when bitmask is applied.

relm.define_element({
  name = constants.GUI.ENCODER_DIALOG_ELEMENT_NAME,
  render = function(props)
    ---@cast props C2CC.EncoderDialogProps
    local mask = utils.to_int32(props.mask or 0)
    local on_change_mask = props.on_change_mask

    local bit_buttons = {}
    for bit = 0, 31 do
      local is_set = bit32.btest(mask, bit32.lshift(1, bit))
      bit_buttons[#bit_buttons + 1] = ultros.Button({
        caption = tostring(bit),
        style = is_set and "relm_selected_standalone_slot_button_grey" or "relm_standalone_slot_button_grey",
        width = 36,
        height = 36,
        on_click = function()
          local new_mask = bit32.bxor(mask, bit32.lshift(1, bit))
          if on_change_mask then on_change_mask(new_mask) end
        end
      })
    end

    return Pr({
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
      top_margin = 6
    }, {
      VF({
        HF({ vertical_align = "center" }, {
          ultros.BoldLabel("Decimal: "),
          ultros.RtMultilineLabel(tostring(utils.to_int32(mask)))
        }),
        Pr({ type = "table", column_count = 8, style = "slot_table" }, bit_buttons),
        HF({ vertical_align = "center", top_margin = 4 }, {
          ultros.Button({
            caption = CAPTION_ENCODER_ALL,
            on_click = function()
              if on_change_mask then on_change_mask(0xFFFFFFFF) end
            end
          }),
          ultros.Button({
            caption = CAPTION_ENCODER_NONE,
            on_click = function()
              if on_change_mask then on_change_mask(0) end
            end
          })
        })
      })
    })
  end
})
