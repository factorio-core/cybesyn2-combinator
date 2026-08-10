local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"
local GuiState = require "scripts.models.gui_state"
local constants = require "scripts.constants"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

---@class C2CC.SettingsTabProps : Relm.Props
---@field public player_index integer Player index.
---@field public update fun() Update callback to trigger UI re-render.

local C = constants.CAPTIONS

relm.define_element({
  name = constants.GUI.SETTINGS_TAB_ELEMENT_NAME,
  render = function(props)
    ---@cast props C2CC.SettingsTabProps
    local playerIndex = props.player_index
    local player = game and game.get_player(playerIndex)
    local isAdmin = (player and player.admin == true) or false
    local update = props.update
    local gs = GuiState.Get(playerIndex)

    return VF({
      bottom_margin = 6
    }, {
      ultros.WellSection({ caption = C.PLAYER_SETTINGS }, {
        VF({}, {
          Pr({
            type = "checkbox",
            caption = C.NEGATIVE_SIGNALS,
            state = gs.GuiSettings.NegativeSignals,
            listen = true,
            message_handler = ultros.handle_gui_events(
              defines.events.on_gui_checked_state_changed,
              function(_, guiEvent)
                if guiEvent.element and guiEvent.element.valid then
                  gs.GuiSettings:SetNegativeSignals(guiEvent.element.state)
                  update()
                end
              end
            )
          }),

          Pr({
            type = "checkbox",
            caption = C.AUTO_QUERY_PRIORITIES,
            state = gs.GuiSettings.AutoQueryPriorities,
            top_margin = 4,
            listen = true,
            message_handler = ultros.handle_gui_events(
              defines.events.on_gui_checked_state_changed,
              function(_, guiEvent)
                if guiEvent.element and guiEvent.element.valid then
                  gs.GuiSettings:SetAutoQueryPriorities(guiEvent.element.state)
                  update()
                end
              end
            )
          }),

          HF({ vertical_align = "center", top_margin = 8 }, {
            ultros.BoldLabel(C.DEFAULT_PRIORITY),
            ultros.Input({
              text = tostring(gs.GuiSettings.Priority or 10),
              numeric = true,
              allow_negative = true,
              width = 80,
              on_change = function(_, _, element)
                gs.GuiSettings:SetPriority(element.text)
                update()
              end
            })
          }),

          Pr({
            type = "checkbox",
            caption = C.APPLY_PRIORITY_ALL,
            state = gs.GuiSettings.ChangeOldPriority,
            top_margin = 4,
            listen = true,
            message_handler = ultros.handle_gui_events(
              defines.events.on_gui_checked_state_changed,
              function(_, guiEvent)
                if guiEvent.element and guiEvent.element.valid then
                  gs.GuiSettings:SetChangeOldPriority(guiEvent.element.state)
                  update()
                end
              end
            )
          }),

          HF({ vertical_align = "center", top_margin = 8 }, {
            ultros.BoldLabel(C.DEFAULT_NETWORK_SIGNAL),
            Pr({
              type = "choose-elem-button",
              elem_type = "signal",
              elem_value = gs.GuiSettings.DefaultNetworkSignal,
              style = "relm_slot_button_default",
              listen = true,
              message_handler = ultros.handle_gui_events(
                defines.events.on_gui_elem_changed,
                function(_, guiEvent)
                  local sig = guiEvent.element and guiEvent.element.elem_value
                  if sig and sig.name then
                    gs.GuiSettings:SetDefaultNetworkSignal(sig)
                    update()
                  end
                end
              )
            })
          }),

          HF({ vertical_align = "center", top_margin = 8 }, {
            ultros.BoldLabel(C.DEFAULT_NETWORK_MASK),
            ultros.Input({
              text = tostring(gs.GuiSettings.NetworkFlag or 1),
              numeric = true,
              allow_negative = true,
              width = 100,
              on_change = function(_, _, element)
                gs.GuiSettings:SetNetworkFlag(element.text)
                update()
              end
            }),
            ultros.Button({
              caption = gs.GuiSettings.EncoderOpen and C.CLOSE_ENCODER or C.OPEN_ENCODER,
              style = gs.GuiSettings.EncoderOpen and "red_button" or "button",
              on_click = function()
                gs.GuiSettings:SetEncoderOpen(not gs.GuiSettings.EncoderOpen)
                update()
              end
            })
          }),

          Pr({
            type = "checkbox",
            caption = C.APPLY_NETWORK_ALL,
            state = gs.GuiSettings.ChangeOldNetwork,
            top_margin = 4,
            listen = true,
            message_handler = ultros.handle_gui_events(
              defines.events.on_gui_checked_state_changed,
              function(_, guiEvent)
                if guiEvent.element and guiEvent.element.valid then
                  gs.GuiSettings:SetChangeOldNetwork(guiEvent.element.state)
                  update()
                end
              end
            )
          }),

          gs.GuiSettings.EncoderOpen and relm.element(constants.GUI.ENCODER_DIALOG_ELEMENT_NAME, {
            mask = gs.GuiSettings.NetworkFlag,
            on_change_mask = function(newMask)
                gs.GuiSettings:SetNetworkFlag(newMask)
                update()
            end
          }) or nil,

          HF({ vertical_align = "center", top_margin = 8 }, {
            ultros.BoldLabel(C.DEFAULT_STACKS),
            ultros.Input({
              text = tostring(gs.GuiSettings.Stacks or 0),
              numeric = true,
              allow_negative = true,
              width = 80,
              on_change = function(_, _, element)
                gs.GuiSettings:SetStacks(element.text)
                update()
              end
            })
          }),

          HF({ vertical_align = "center", top_margin = 8 }, {
            ultros.BoldLabel(C.DEFAULT_COUNT),
            ultros.Input({
              text = tostring(gs.GuiSettings.Count or 0),
              numeric = true,
              allow_negative = true,
              width = 100,
              on_change = function(_, _, element)
                gs.GuiSettings:SetCount(element.text)
                update()
              end
            })
          }),

          HF({ vertical_align = "center", top_margin = 8 }, {
            ultros.BoldLabel(C.DEFAULT_INPUT_MODE),
            ultros.Button({
              caption = C.INPUT_MODE_COUNTS,
              style = gs.GuiSettings.DefaultInputMode == constants.INPUT_MODE.COUNT and "confirm_button" or "button",
              height = 28,
              on_click = function()
                gs.GuiSettings:SetDefaultInputMode(constants.INPUT_MODE.COUNT)
                update()
              end
            }),
            ultros.Button({
              caption = C.INPUT_MODE_STACKS,
              style = gs.GuiSettings.DefaultInputMode == constants.INPUT_MODE.STACKS and "confirm_button" or "button",
              height = 28,
              on_click = function()
                gs.GuiSettings:SetDefaultInputMode(constants.INPUT_MODE.STACKS)
                update()
              end
            })
          }),

          gs.GuiSettings.StatusMessage ~= "" and Pr({
            type = "label",
            caption = "[color=yellow]" .. gs.GuiSettings.StatusMessage .. "[/color]",
            top_margin = 6
          }) or nil,

          HF({ vertical_align = "center", top_margin = 12 }, {
            ultros.Button({
              caption = C.SAVE_SETTINGS,
              style = "confirm_button",
              width = 150,
              height = 30,
              on_click = function()
                gs:SaveSettings(isAdmin)
                update()
              end
            }),
            ultros.Button({
              caption = C.CANCEL,
              style = "button",
              width = 150,
              height = 30,
              on_click = function()
                gs:CancelSettings()
                update()
              end
            })
          })
        })
      })
    })
  end
})
