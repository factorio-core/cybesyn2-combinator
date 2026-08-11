local relm = require("__cybersyn2-combinator__/lib/core/relm/relm")
local ultros = require("__cybersyn2-combinator__/lib/core/relm/ultros")
local utils = require "scripts.gui.utils"
local constants = require "scripts.constants"
local networks = require "scripts.gui.networks"

local Pr = relm.Primitive
local VF = ultros.VFlow

---@class C2CC.NetworksDialogProps : Relm.Props
---@field public on_select_network? fun(signal: SignalID, count: integer)

local C = constants.CAPTIONS

relm.define_element({
  name = constants.GUI.NETWORKS_DIALOG_ELEMENT_NAME,
  render = function(props)
    ---@cast props C2CC.NetworksDialogProps
    local on_select_network = props.on_select_network

    ---Networks data is fetched lazily: only queried when this component renders.
    ---The component is conditionally rendered in main.lua only when
    ---gs.GuiMain.NetworksOpen is true (triggered by "Open Networks" button press).
    local networks_data = networks.get_all_global_active_networks()

    local net_buttons = {}
    for _, data_net in ipairs(networks_data) do
      net_buttons[#net_buttons + 1] = Pr({
        type = "choose-elem-button",
        elem_type = "signal",
        elem_value = data_net.Signal,
        style = "relm_slot_button_default",
        listen = true,
        message_handler = ultros.handle_gui_events(
          defines.events.on_gui_elem_changed,
          function(_, gui_event)
            local elem = gui_event.element
            if elem and elem.valid then
              elem.elem_value = data_net.Signal
            end
            if on_select_network then on_select_network(data_net.Signal, data_net.Count) end
          end
        )
      }, {
        data_net.Count ~= 0 and Pr({
          type = "label",
          style = "relm_label_signal_count",
          caption = utils.format_short_number(data_net.Count),
          ignored_by_interaction = true
        }) or nil
      })
    end

    return Pr({
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
      top_margin = 6
    }, {
      VF({
        ultros.BoldLabel(C.ACTIVE_GLOBAL_NETWORKS),
        #net_buttons > 0 and Pr({
          type = "scroll-pane",
          style = "scroll_pane",
          direction = "vertical",
          vertical_scroll_policy = "auto",
          horizontal_scroll_policy = "never",
          minimal_height = 44,
          maximal_height = 180,
          horizontally_stretchable = true
        }, {
          VF({
            horizontal_align = "center",
            horizontally_stretchable = true
          }, {
            Pr({ type = "table", column_count = 8 }, net_buttons)
          })
        })
        or ultros.RtMultilineLabel(C.NO_ACTIVE_NETWORKS)
      })
    })
  end
})
