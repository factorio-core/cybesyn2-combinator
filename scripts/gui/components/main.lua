local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local constants = require "scripts.constants"
local utils = require "scripts.gui.utils"
local GuiState = require "scripts.models.gui_state"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

local C = constants.CAPTIONS

local function buildGroupElements(gs, groups, playerIndex, update)
  local elements = {}
  for _, grp in ipairs(groups) do
    elements[#elements + 1] = relm.element(constants.GUI.SECTION_GROUP_ELEMENT_NAME, {
      grp = grp,
      groups_count = #groups,
      selected_section = gs.GuiMain.SelectedSection,
      selected_slot = gs.GuiMain.SelectedSlot,
      combinator = gs.Combinator,
      player_index = playerIndex,
      update = update,
      on_select_slot = function(secIdx, slotIdx)
        gs:OnSlotClicked(secIdx, slotIdx)
        update()
      end,
      on_reset_selection = function()
        gs:ResetSelection()
        update()
      end,
    })
  end
  return elements
end

relm.define_element({
  name = constants.GUI.MAIN_ELEMENT_NAME,
  render = function(props)
    ---@cast props C2CC.MainProps
    if not game then return nil end
    local rootId = props.root_id
    local playerIndex = props.player_index
    local player = game.get_player(playerIndex)

    local function closeMe()
      local elt = relm.get_root_element(rootId)
      if elt and player and player.opened == elt then
        player.opened = nil
      end
      relm.root_destroy(rootId)
    end
    local closeHandler = ultros.use_memoized_window_position(
      closeMe,
      function() return nil end,
      function() end,
      function(elt)
        if elt and elt.valid and elt.type == "frame" then
          elt.force_auto_center()
        end
      end
    )
    ultros.use_close_on_gui_closed(playerIndex, closeHandler, false)

    local entity = props.entity
    if not entity or not entity.valid then return nil end

    local me = relm.use_handle()
    local function update()
      relm.paint(me)
    end

    local gs = GuiState.Get(playerIndex, entity)

    local stats = gs:GetStatistics()
    local totalItems = stats.totalItems
    local totalItemStacks = stats.totalItemStacks
    local totalFluids = stats.totalFluids

    local isStacksEnabled = gs:IsStacksEnabled()

    return ultros.WindowFrame({
      caption = C.TITLE,
      on_close = closeHandler,
    }, {
      Pr({
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
        width = 448
      }, {
        HF({ bottom_margin = 6 }, {
          ultros.Button({
            caption = C.TAB_COMBINATOR,
            style = (gs.GuiMain.ActiveTab or "combinator") == "combinator" and "confirm_button" or "button",
            height = 28,
            on_click = function()
              gs:SetActiveTab("combinator")
              gs:SetTargetFocusField(gs:GetTargetFocusFieldName(gs.Combinator))
              update()
            end
          }),
          ultros.Button({
            caption = C.TAB_SETTINGS,
            style = (gs.GuiMain.ActiveTab or "combinator") == "settings" and "confirm_button" or "button",
            height = 28,
            on_click = function()
              gs:SetActiveTab("settings")
              update()
            end
          })
        }),

        (gs.GuiMain.ActiveTab or "combinator") == "settings" and relm.element(constants.GUI.SETTINGS_TAB_ELEMENT_NAME, {
          player_index = playerIndex, update = update
        }) or VF({
          HF({ vertical_align = "center" }, {
            ultros.BoldLabel(gs.Combinator:IsEnabled() and C.STATUS_WORKING or C.STATUS_DISABLED),
            ultros.Button({
              caption = gs.Combinator:IsEnabled() and C.OUTPUT_ON or C.OUTPUT_OFF,
              style = gs.Combinator:IsEnabled() and "confirm_button" or "red_button",
              width = 140,
              height = 28,
              on_click = function()
                gs:ToggleEnabled()
                update()
              end
            })
          }),

          ultros.WellSection({ caption = C.CYBERSYN_PARAMETERS }, {
            VF({}, {
              HF({ vertical_align = "center" }, {
                Pr({
                  type = "choose-elem-button",
                  elem_type = "signal",
                  elem_value = { type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME },
                  enabled = false,
                  style = "relm_slot_button_default"
                }, {
                  gs.Combinator:GetPriority() ~= 0 and Pr({
                    type = "label",
                    style = "relm_label_signal_count",
                    caption = utils.format_short_number(gs.Combinator:GetPriority()),
                    ignored_by_interaction = true
                  }) or nil
                }),
                ultros.BoldLabel(C.STATION_PRIORITY),
                ultros.Input({
                  text = tostring(gs.GuiMain.EditPriority),
                  numeric = true,
                  allow_negative = true,
                  lose_focus_on_confirm = false,
                  width = 80,
                  on_change = function(_, _, element)
                    gs:SetCombinatorPriority(element.text)
                    update()
                  end,
                })
              }),

              relm.element(constants.GUI.PRIORITIES_SUMMARY_ELEMENT_NAME, {
                player_index = playerIndex,
                update = update,
              })
            })
          }),

          ultros.WellSection({ caption = C.NETWORK_LIST_TITLE }, {
            VF({
              HF({ vertical_align = "center" }, {
                Pr({
                  type = "choose-elem-button",
                  elem_type = "signal",
                  elem_value = (gs.Combinator:GetNetworkSignal() or {}).Signal,
                  style = "relm_slot_button_default",
                  listen = true,
                  message_handler = ultros.handle_gui_events(
                    defines.events.on_gui_elem_changed,
                    function(_, guiEvent)
                      local sig = guiEvent.element and guiEvent.element.elem_value
                      gs:ChangeNetworkSignal(sig)
                      update()
                    end
                  )
                }, {
                  gs:GetNetworkCount() ~= 0 and Pr({
                    type = "label",
                    style = "relm_label_signal_count",
                    caption = utils.format_short_number(gs:GetNetworkCount()),
                    ignored_by_interaction = true
                  }) or nil
                }),
                ultros.Input({
                  text = tostring(gs.GuiMain.EditNetworkValue),
                  numeric = true,
                  allow_negative = true,
                  lose_focus_on_confirm = false,
                  width = 80,
                  on_change = function(_, _, element)
                    gs:ChangeNetworkValue(element.text)
                    update()
                  end
                }),
                ultros.Button({
                  caption = gs.GuiMain.EncoderOpen and C.CLOSE_ENCODER or C.OPEN_ENCODER,
                  style = gs.GuiMain.EncoderOpen and "red_button" or "button",
                  on_click = function()
                    gs:ToggleEncoder()
                    update()
                  end
                }),
                ultros.Button({
                  caption = gs.GuiMain.NetworksOpen and C.CLOSE_NETWORKS or C.OPEN_NETWORKS,
                  style = gs.GuiMain.NetworksOpen and "red_button" or "button",
                  on_click = function()
                    gs:ToggleNetworks()
                    update()
                  end
                })
              }),

              gs.GuiMain.EncoderOpen and relm.element(constants.GUI.ENCODER_DIALOG_ELEMENT_NAME, {
                mask = gs:GetNetworkCount(),
                on_change_mask = function(newMask)
                  gs:ChangeNetworkValue(newMask)
                  update()
                end
              }) or nil,
              gs.GuiMain.NetworksOpen and relm.element(constants.GUI.NETWORKS_DIALOG_ELEMENT_NAME, {
                on_select_network = function(sig, count)
                  gs:SelectGlobalNetwork(sig, count)
                  update()
                end
              }) or nil,
            })
          }),

          ultros.WellSection({ caption = C.OUTPUT_SIGNALS }, {
            VF({
              HF({ vertical_align = "center", bottom_margin = 6 }, {
                Pr({ type = "frame", style = "inside_shallow_frame_with_padding" }, {
                  ultros.RtMultilineLabel({ C.ITEMS_SUMMARY, totalItems, totalItemStacks })
                }),
                Pr({ type = "frame", style = "inside_shallow_frame_with_padding" }, {
                  ultros.RtMultilineLabel({ C.FLUIDS_SUMMARY, totalFluids })
                })
              }),

              HF({ vertical_align = "center", bottom_margin = 6 }, {
                ultros.BoldLabel(C.STACKS),
                ultros.Input({
                  name = constants.GUI.FIELD_EDIT_STACKS,
                  ref = function(elt)
                    if elt and elt.valid and gs.GuiMain.TargetFocusField == constants.GUI.FIELD_EDIT_STACKS then
                      elt.focus()
                      gs:SetTargetFocusField(nil)
                    end
                  end,
                  text = gs:FormatInputText(gs.GuiMain.EditStacks),
                  numeric = true,
                  allow_negative = true,
                  enabled = isStacksEnabled,
                  width = 65,
                  on_change = function(_, _, element)
                    if isStacksEnabled then
                      gs:ChangeEditStacks(element.text)
                      update()
                    end
                  end
                }),
                ultros.BoldLabel(C.COUNT),
                ultros.Input({
                  name = constants.GUI.FIELD_EDIT_COUNT,
                  ref = function(elt)
                    if elt and elt.valid and gs.GuiMain.TargetFocusField == constants.GUI.FIELD_EDIT_COUNT then
                      elt.focus()
                      gs:SetTargetFocusField(nil)
                    end
                  end,
                  text = gs:FormatInputText(gs.GuiMain.EditItems),
                  numeric = true,
                  allow_negative = true,
                  width = 65,
                  on_change = function(_, _, element)
                    gs:ChangeEditItems(element.text)
                    update()
                  end
                })
              }),

              Pr({
                name = constants.GUI.GROUPS_SCROLL_PANE,
                type = "scroll-pane",
                style = "deep_slots_scroll_pane",
                direction = "vertical",
                vertical_scroll_policy = "auto",
                horizontal_scroll_policy = "never",
                height = 400,
                maximal_height = 400,
                horizontally_stretchable = true
              }, {
                VF({
                  horizontally_stretchable = true,
                  horizontally_squashable = false
                }, {
                  VF(buildGroupElements(gs, gs.Combinator:GetGroups(), playerIndex, update)),

                  ultros.Button({
                    caption = C.ADD_SECTION,
                    horizontally_stretchable = true,
                    top_margin = 4,
                    on_click = function()
                      gs:ResetSelection()
                      gs:AddGroup()
                      utils.scroll_pane_to_bottom(playerIndex, "c2cc_groups_scroll")
                      update()
                    end
                  })
                })
              })
            })
          })
        })
      })
    })
  end
})
