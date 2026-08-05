local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local relm_util = require "__0-things__.lib.core.relm.util"
local constants = require "scripts.constants"
local C2CC = require "scripts.combinator"
local utils = require "scripts.gui.utils"
local handlers = require "scripts.gui.handlers"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

---@class C2CC.MainProps : Relm.Props
---@field public entity LuaEntity The Factorio combinator entity.
---@field public thing_id integer 0-things thing ID.
---@field public root_id Relm.RootId Root ID of the Relm window.
---@field public player_index integer Player index.

--------------------------------------------------------------------------------
-- Main Combinator Window Element Definition (Pure Reactive State Architecture)
--------------------------------------------------------------------------------

relm.define_element({
  name = "C2CC.Main",
  render = function(props)
    ---@cast props C2CC.MainProps
    local root_id = props.root_id
    local player_index = props.player_index
    local player = game.get_player(player_index)

    local function _close_me()
      local elt = relm.get_root_element(root_id)
      if elt and player and player.opened == elt then
        player.opened = nil
      end
      relm.root_destroy(root_id)
    end
    local close_me = ultros.use_memoized_window_position(
      _close_me,
      function() return nil end,
      function() end,
      function(elt)
        if elt and elt.valid and elt.type == "frame" then
          elt.force_auto_center()
        end
      end
    )
    ultros.use_close_on_gui_closed(player_index, close_me, false)

    local entity = props.entity
    if not entity or not entity.valid then return nil end

    local combinator = C2CC:new(entity, false)

    relm_util.use_event_handler(
      constants.EVENTS.ON_STATUS,
      function(_, _, ev)
        if ev.thing.id == props.thing_id and (ev.new_status == "void" or ev.new_status == "destroyed") then
          close_me()
        end
      end
    )

    local default_stks = utils.get_default_stacks(player_index)
    local default_cnt = utils.get_default_count(player_index)

    local is_enabled, set_is_enabled = relm.use_state(combinator:is_enabled())
    local raw_priority = combinator:get_priority()
    local default_prio = utils.get_default_priority()
    if raw_priority == 0 and default_prio ~= 0 then
      combinator:set_priority(default_prio)
      raw_priority = default_prio
    end
    local priority, set_priority = relm.use_state(raw_priority)

    local groups, set_groups = relm.use_state(function() return combinator:get_groups() end)

    local gs = utils.get_gui_state(player_index)
    local sign = utils.is_negative_signals_enabled(player_index) and -1 or 1

    local edit_items_text, set_edit_items_text = relm.use_state(function() return gs.edit_items_text or default_cnt end)
    local edit_stacks_text, set_edit_stacks_text = relm.use_state(function() return gs.edit_stacks_text or default_stks end)

    local selected_section, set_selected_section = relm.use_state(function() return gs.selected_section end)
    local selected_slot, set_selected_slot = relm.use_state(function() return gs.selected_slot end)

    local focus_slot_token, set_focus_slot_token = relm.use_state(nil)

    local encoder_open, set_encoder_open = relm.use_state(false)
    local encoder_mask, set_encoder_mask = relm.use_state(0)
    local networks_open, set_networks_open = relm.use_state(false)

    local net_signals = combinator:get_network_signals()

    if #net_signals == 0 then
      local default_net = utils.get_default_network_flag()
      if default_net ~= 0 then
        local init_sig = { type = "virtual", name = "signal-A" }
        combinator:set_network_signals({ { signal = init_sig, count = default_net } })
        net_signals = combinator:get_network_signals()
      end
    end

    local current_net_data = net_signals[1]
    local init_net_sig = (current_net_data and current_net_data.signal) or { type = "virtual", name = "signal-A" }
    local init_net_val = (current_net_data and current_net_data.count) or utils.get_default_network_flag()

    local new_mask_signal, set_new_mask_signal = relm.use_state(init_net_sig)
    local new_mask_val, set_new_mask_val = relm.use_state(init_net_val)

    local cur_net_sig = new_mask_signal or init_net_sig
    local cur_net_val = tonumber(new_mask_val) or init_net_val

    local total_items = 0
    local total_item_stacks = 0
    local total_fluids = 0

    for _, grp in ipairs(groups) do
      for _, sdata in pairs(grp.slots) do
        if sdata and sdata.signal then
          local sig_type = sdata.signal.type or "item"
          if sig_type == "fluid" then
            total_fluids = total_fluids + math.abs(sdata.count)
          elseif sig_type == "item" then
            local s_size = utils.get_stack_size(sdata.signal)
            local stks = math.ceil(math.abs(sdata.count) / s_size)
            total_items = total_items + math.abs(sdata.count)
            total_item_stacks = total_item_stacks + stks
          end
        end
      end
    end

    -- Determine if currently selected signal supports stacks (items only, not fluids/virtuals)
    local selected_signal = nil
    if selected_section and selected_slot then
      for _, grp in ipairs(groups) do
        if grp.section_index == selected_section then
          local sdata = grp.slots[selected_slot]
          if sdata and sdata.signal then
            selected_signal = sdata.signal
          end
          break
        end
      end
    end

    local is_stacks_enabled = (selected_signal == nil) or utils.is_stackable_signal(selected_signal)
    local target_focus_field = focus_slot_token and (is_stacks_enabled and "stacks" or "count") or nil

    ----------------------------------------------------------------------------
    -- Render Group Components
    ----------------------------------------------------------------------------

    local function reset_selection()
      set_selected_section(nil)
      set_selected_slot(nil)
      set_focus_slot_token(nil)
    end

    local group_elements = {}
    for g_idx, grp in ipairs(groups) do
      group_elements[#group_elements + 1] = relm.element("C2CC.SectionGroup", {
        grp = grp,
        groups_count = #groups,
        selected_section = selected_section,
        selected_slot = selected_slot,
        combinator = combinator,
        edit_items_text = edit_items_text,
        edit_stacks_text = edit_stacks_text,
        sign = sign,
        player_index = player_index,
        on_select_slot = function(sec_idx, slot_idx)
          handlers.group_slot_clicked(combinator, player_index, sign, sec_idx, slot_idx, set_edit_items_text, set_edit_stacks_text, set_selected_section, set_selected_slot, set_focus_slot_token)
        end,
        on_reset_selection = reset_selection,
        set_groups = set_groups
      })
    end

    local display_stacks = utils.format_input_text(edit_stacks_text, sign)
    local display_count = utils.format_input_text(edit_items_text, sign)

    return ultros.WindowFrame({
      caption = "Cybersyn 2 Constant Combinator",
      on_close = close_me,
    }, {
      Pr({
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
        width = 448
      }, {
        VF({
          HF({ vertical_align = "center" }, {
            ultros.BoldLabel(is_enabled and "● Working" or "○ Disabled"),
            ultros.Button({
              caption = is_enabled and "Output: On" or "Output: Off",
              style = is_enabled and "confirm_button" or "red_button",
              width = 140,
              height = 28,
              on_click = function()
                handlers.toggle_enabled(combinator, is_enabled, set_is_enabled)
              end
            })
          }),

          ultros.WellSection({ caption = "Cybersyn Parameters" }, {
            HF({ vertical_align = "center" }, {
              Pr({
                type = "choose-elem-button",
                elem_type = "signal",
                elem_value = { type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME },
                enabled = false,
                style = "relm_slot_button_default"
              }, {
                priority ~= 0 and Pr({
                  type = "label",
                  style = "relm_label_signal_count",
                  caption = utils.format_short_number(priority),
                  ignored_by_interaction = true
                }) or nil
              }),
              ultros.BoldLabel("Station Priority:"),
              ultros.Input({
                text = tostring(priority),
                lose_focus_on_confirm = false,
                width = 80,
                on_change = function(_, val)
                  handlers.change_priority(combinator, val, set_priority)
                end,
                on_confirm = function(_, val)
                  handlers.change_priority(combinator, val, set_priority)
                end
              })
            })
          }),

          ultros.WellSection({ caption = { "cybersyn2-constant-combinator-window.network-list-title" } }, {
            VF({
              HF({ vertical_align = "center" }, {
                Pr({
                  type = "choose-elem-button",
                  elem_type = "signal",
                  elem_value = cur_net_sig,
                  style = "relm_slot_button_default",
                  listen = true,
                  message_handler = ultros.handle_gui_events(
                    defines.events.on_gui_elem_changed,
                    function(_, gui_event)
                      local sig = gui_event.element and gui_event.element.elem_value
                      handlers.change_new_mask_signal(combinator, gs, sig, cur_net_val, set_new_mask_signal, set_groups)
                    end
                  )
                }, {
                  cur_net_val ~= 0 and Pr({
                    type = "label",
                    style = "relm_label_signal_count",
                    caption = utils.format_short_number(cur_net_val),
                    ignored_by_interaction = true
                  }) or nil
                }),
                ultros.Input({
                  text = tostring(new_mask_val),
                  lose_focus_on_confirm = false,
                  width = 80,
                  on_change = function(_, val)
                    handlers.change_new_mask_val(combinator, gs, new_mask_signal, val, set_new_mask_val)
                  end
                }),
                ultros.Button({
                  caption = encoder_open and "Close Encoder" or "Open Encoder",
                  style = encoder_open and "red_button" or "button",
                  on_click = function()
                    handlers.toggle_encoder(encoder_open, new_mask_val, set_encoder_open, set_networks_open, set_encoder_mask)
                  end
                }),
                ultros.Button({
                  caption = networks_open and "Close Networks" or "Open Networks",
                  style = networks_open and "red_button" or "button",
                  on_click = function()
                    handlers.toggle_networks(networks_open, set_networks_open, set_encoder_open)
                  end
                })
              }),

              encoder_open and relm.element("C2CC.EncoderDialog", {
                mask = cur_net_val,
                on_change_mask = function(new_mask)
                  handlers.change_new_mask_val(combinator, gs, new_mask_signal, new_mask, set_new_mask_val)
                end,
                on_apply = function(mask_val)
                  handlers.encoder_apply(combinator, gs, new_mask_signal, mask_val, set_encoder_open, set_new_mask_val, set_encoder_mask)
                end
              }) or nil,
              networks_open and relm.element("C2CC.NetworksDialog", {
                on_select_network = function(sig, count)
                  handlers.select_global_network(combinator, gs, sig, count, set_new_mask_signal, set_new_mask_val, set_networks_open)
                end
              }) or nil,
            })
          }),

          ultros.WellSection({ caption = "Output Signals" }, {
            VF({
              HF({ vertical_align = "center", bottom_margin = 6 }, {
                Pr({ type = "frame", style = "inside_shallow_frame_with_padding" }, {
                  ultros.RtMultilineLabel("Items: " .. total_items .. " (" .. total_item_stacks .. " stacks)")
                }),
                Pr({ type = "frame", style = "inside_shallow_frame_with_padding" }, {
                  ultros.RtMultilineLabel("Fluids: " .. total_fluids)
                })
              }),

              HF({ vertical_align = "center", bottom_margin = 6 }, {
                ultros.BoldLabel("Stacks:"),
                ultros.Input({
                  name = "c2cc_edit_stacks",
                  ref = function(elt)
                    if elt and elt.valid and target_focus_field == "stacks" then
                      elt.focus()
                      set_focus_slot_token(nil)
                    end
                  end,
                  text = display_stacks,
                  enabled = is_stacks_enabled,
                  width = 65,
                  on_change = function(_, val)
                    if is_stacks_enabled then
                      handlers.change_edit_stacks(combinator, player_index, selected_section, selected_slot, edit_items_text, sign, val, set_edit_stacks_text, set_groups)
                    end
                  end
                }),
                ultros.BoldLabel("Count:"),
                ultros.Input({
                  name = "c2cc_edit_count",
                  ref = function(elt)
                    if elt and elt.valid and target_focus_field == "count" then
                      elt.focus()
                      set_focus_slot_token(nil)
                    end
                  end,
                  text = display_count,
                  width = 85,
                  on_change = function(_, val)
                    handlers.change_edit_items(combinator, player_index, selected_section, selected_slot, edit_stacks_text, sign, val, set_edit_items_text, set_groups)
                  end
                })
              }),

              Pr({
                name = "c2cc_groups_scroll",
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
                  VF(group_elements),

                  ultros.Button({
                    caption = { "gui-logistic.add-section" },
                    horizontally_stretchable = true,
                    top_margin = 4,
                    on_click = function()
                      reset_selection()
                      handlers.add_group(combinator, set_groups)
                      utils.scroll_pane_to_bottom(player_index, "c2cc_groups_scroll")
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
