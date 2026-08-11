local relm = require "__cybersyn2-combinator__.lib.core.relm.relm"
local ultros = require "__cybersyn2-combinator__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"
local GuiState = require "scripts.models.gui_state"
local constants = require "scripts.constants"
local relm_util = require "__cybersyn2-combinator__.lib.core.relm.util"
local priorities = require "scripts.gui.priorities"

local Pr = relm.Primitive
local VF = ultros.VFlow

local C = constants.CAPTIONS
local MSG_REFRESH_PRIORITIES = constants.MESSAGES.REFRESH_PRIORITIES
local PRIO_SCROLL_PANE = "c2cc_prio_scroll"
local PRIO_ROW_PREFIX = "c2cc_prio_row_"

local COLOR_REQ_MIN = { r = 0.45, g = 0.75, b = 1.0 }
local COLOR_REQ_MAX = { r = 0.15, g = 0.40, b = 0.85 }
local COLOR_SUP_MIN = { r = 1.0, g = 0.55, b = 0.55 }
local COLOR_SUP_MAX = { r = 0.80, g = 0.20, b = 0.20 }

local function priorityButton(val, colorTint, tooltip)
  return Pr({
    type = "choose-elem-button",
    elem_type = "signal",
    elem_value = { type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME },
    enabled = false,
    style = "relm_slot_button_default",
    tooltip = tooltip,
  }, {
    val ~= nil and Pr({
      type = "label",
      style = "relm_label_signal_count",
      caption = utils.format_short_number(val),
      font_color = colorTint,
      ignored_by_interaction = true,
    }) or Pr({
      type = "label",
      style = "relm_label_signal_count",
      caption = "-",
      font_color = colorTint,
      ignored_by_interaction = true,
    })
  })
end

relm.define_element({
  name = constants.GUI.PRIORITIES_SUMMARY_ELEMENT_NAME,

  message = function(me, payload, props)
    if payload and payload.key == MSG_REFRESH_PRIORITIES then
      local playerIndex = props and props.player_index
      if not playerIndex then return false end
      local gs = GuiState.Get(playerIndex)
      if not gs or gs.PlayerSettings.AutoQueryPriorities == false then return false end
      if gs.Combinator and gs.Combinator.Entity and gs.Combinator.Entity.valid then
        local info = storage.opened_info and storage.opened_info[playerIndex]
        local cached_inv_ids = info and info.target_inv_ids or nil
        local newPriorities = priorities.query_signal_priorities(gs.Combinator.Entity, cached_inv_ids)
        if not priorities.are_priorities_equal(gs.PrioritiesCache, newPriorities) then
          gs.PrioritiesCache = newPriorities
          relm.paint(me)
          return true
        end
      end
    end
    return false
  end,

  render = function(props)
    local playerIndex = props and props.player_index
    if not playerIndex then return nil end
    local gs = GuiState.Get(playerIndex)
    if not gs or gs.PlayerSettings.AutoQueryPriorities == false then return nil end

    relm_util.use_timer(300, MSG_REFRESH_PRIORITIES)

    if not gs.PrioritiesCache then
      local info = storage.opened_info and storage.opened_info[playerIndex]
      local cached_inv_ids = info and info.target_inv_ids or nil
      gs.PrioritiesCache = priorities.query_signal_priorities(gs.Combinator.Entity, cached_inv_ids)
    end

    local signalPriorities = gs.PrioritiesCache
    if not signalPriorities or #signalPriorities == 0 then return nil end

    local highlighted = props.highlighted_signal_name
    local scrollPaneEl = nil

    local cells = {}
    for _, entry in ipairs(signalPriorities) do
      local sig = entry.signal
      local reqMin = entry.req_found and (entry.req_min or 0) or nil
      local reqMax = entry.req_found and (entry.req_max or 0) or nil
      local supMin = entry.sup_found and (entry.sup_min or 0) or nil
      local supMax = entry.sup_found and (entry.sup_max or 0) or nil
      local isMatch = highlighted and sig.name == highlighted

      cells[#cells + 1] = Pr({
        type = "choose-elem-button",
        elem_type = "signal",
        elem_value = sig,
        enabled = false,
        style = isMatch and "relm_selected_slot_button_default" or "relm_slot_button_default",
        name = isMatch and (PRIO_ROW_PREFIX .. (sig.name or "")) or nil,
        ref = isMatch and function(el)
          if el and el.valid and scrollPaneEl and scrollPaneEl.valid then
            scrollPaneEl.scroll_to_element(el)
          end
        end or nil,
      })

      cells[#cells + 1] = priorityButton(reqMin, COLOR_REQ_MIN, { "", C.REQUEST_PRIORITY, " ", C.MIN_PRIORITY })
      cells[#cells + 1] = priorityButton(reqMax, COLOR_REQ_MAX, { "", C.REQUEST_PRIORITY, " ", C.MAX_PRIORITY })
      cells[#cells + 1] = priorityButton(supMin, COLOR_SUP_MIN, { "", C.SUPPLY_PRIORITY, " ", C.MIN_PRIORITY })
      cells[#cells + 1] = priorityButton(supMax, COLOR_SUP_MAX, { "", C.SUPPLY_PRIORITY, " ", C.MAX_PRIORITY })
    end

    return VF({ top_margin = 6 }, {
      Pr({
        type = "scroll-pane",
        name = PRIO_SCROLL_PANE,
        style = "scroll_pane",
        direction = "vertical",
        vertical_scroll_policy = "auto",
        horizontal_scroll_policy = "never",
        maximal_height = 160,
        horizontally_stretchable = true,
        ref = function(el) scrollPaneEl = el end,
      }, {
        Pr({
          type = "table",
          column_count = 5,
          style = "slot_table"
        }, cells)
      })
    })
  end
})
