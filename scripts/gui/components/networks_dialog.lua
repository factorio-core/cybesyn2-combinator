local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"
local constants = require "scripts.constants"

local Pr = relm.Primitive
local VF = ultros.VFlow

---@class C2CC.NetworksDialogProps : Relm.Props
---@field public on_select_network? fun(signal: SignalID, count: integer) Callback when a active global network signal is selected.

relm.define_element({
  name = constants.GUI.NETWORKS_DIALOG_ELEMENT_NAME,
  render = function(props)
    ---@cast props C2CC.NetworksDialogProps
    local on_select_network = props.on_select_network

    local net_buttons = {}
    for key, data_net in pairs(utils.get_all_global_active_networks()) do
      net_buttons[#net_buttons + 1] = Pr({
        type = "choose-elem-button",
        elem_type = "signal",
        elem_value = data_net.Signal,
        style = "relm_slot_button_default",
        locked = true,
        listen = true,
        message_handler = ultros.handle_gui_events(
          defines.events.on_gui_click,
          function()
            if on_select_network then on_select_network(data_net.Signal, data_net.Count) end
          end
        )
      }, {
        Pr({
          type = "label",
          style = "relm_label_signal_count",
          caption = utils.format_short_number(data_net.Count),
          ignored_by_interaction = true
        })
      })
    end

    return Pr({
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
      top_margin = 6
    }, {
      VF({
        ultros.BoldLabel("Active Global Networks:"),
        #net_buttons > 0 and Pr({
          type = "scroll-pane",
          style = "scroll_pane",
          direction = "vertical",
          vertical_scroll_policy = "auto",
          horizontal_scroll_policy = "never",
          maximal_height = 200,
          horizontally_stretchable = true
        }, {
          VF({
            horizontal_align = "center",
            horizontally_stretchable = true
          }, {
            Pr({ type = "table", column_count = 9, style = "slot_table" }, net_buttons)
          })
        })
        or ultros.RtMultilineLabel("(No active networks in world)")
      })
    })
  end
})
