local relm = require "__0-things__.lib.core.relm.relm"
local ultros = require "__0-things__.lib.core.relm.ultros"
local utils = require "scripts.gui.utils"
local GuiState = require "scripts.models.gui_state"
local constants = require "scripts.constants"
local relm_util = require "__0-things__.lib.core.relm.util"
local priorities = require "scripts.gui.priorities"

local Pr = relm.Primitive
local VF = ultros.VFlow
local HF = ultros.HFlow

local C = constants.CAPTIONS
local MSG_REFRESH_PRIORITIES = constants.MESSAGES.REFRESH_PRIORITIES

-- Color tints for cells:
-- Request (Blue): Light blue for Min, Dark blue for Max
local COLOR_REQ_MIN = { r = 0.45, g = 0.75, b = 1.0 }
local COLOR_REQ_MAX = { r = 0.15, g = 0.40, b = 0.85 }

-- Supply (Red): Light red for Min, Dark red for Max
local COLOR_SUP_MIN = { r = 1.0, g = 0.55, b = 0.55 }
local COLOR_SUP_MAX = { r = 0.80, g = 0.20, b = 0.20 }

local function createSignalValueButton(val, colorTint)
  return Pr({
    type = "choose-elem-button",
    elem_type = "signal",
    elem_value = { type = "virtual", name = constants.SETTINGS.CS_PRIORITY_NAME },
    enabled = false,
    style = "relm_slot_button_default"
  }, {
    val ~= nil and Pr({
      type = "label",
      style = "relm_label_signal_count",
      caption = utils.format_short_number(val),
      font_color = colorTint,
      ignored_by_interaction = true
    }) or Pr({
      type = "label",
      style = "relm_label_signal_count",
      caption = "-",
      font_color = colorTint,
      ignored_by_interaction = true
    })
  })
end

local function buildPriorityTableCells(priorities)
  local cells = {}
  for _, entry in ipairs(priorities) do
    local sig = entry.signal
    local reqMin = entry.req_found and (entry.req_min or 0) or nil
    local reqMax = entry.req_found and (entry.req_max or 0) or nil
    local supMin = entry.sup_found and (entry.sup_min or 0) or nil
    local supMax = entry.sup_found and (entry.sup_max or 0) or nil

    -- Column 1: Signal icon
    cells[#cells + 1] = Pr({
      type = "choose-elem-button",
      elem_type = "signal",
      elem_value = sig,
      enabled = false,
      style = "relm_slot_button_default"
    })

    -- Column 2: Request Min (Light Blue)
    cells[#cells + 1] = createSignalValueButton(reqMin, COLOR_REQ_MIN)

    -- Column 3: Request Max (Dark Blue)
    cells[#cells + 1] = createSignalValueButton(reqMax, COLOR_REQ_MAX)

    -- Column 4: Supply Min (Light Red)
    cells[#cells + 1] = createSignalValueButton(supMin, COLOR_SUP_MIN)

    -- Column 5: Supply Max (Dark Red)
    cells[#cells + 1] = createSignalValueButton(supMax, COLOR_SUP_MAX)
  end
  return cells
end

local function ColoredLabel(caption, fontColor)
  return Pr({
    type = "label",
    caption = caption,
    font_color = fontColor
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

    -- Native Relm timer hook: sends MSG_REFRESH_PRIORITIES message every 300 ticks (5s)
    relm_util.use_timer(300, MSG_REFRESH_PRIORITIES)

    if not gs.PrioritiesCache then
      local info = storage.opened_info and storage.opened_info[playerIndex]
      local cached_inv_ids = info and info.target_inv_ids or nil
      gs.PrioritiesCache = priorities.query_signal_priorities(gs.Combinator.Entity, cached_inv_ids)
    end

    local signalPriorities = gs.PrioritiesCache
    if not signalPriorities or #signalPriorities == 0 then return nil end

    return VF({ top_margin = 6 }, {
      HF({ vertical_align = "center", bottom_margin = 2 }, {
        Pr({ type = "empty-widget", width = 36 }),
        Pr({ type = "flow", horizontal_align = "center", width = 76 }, {
          ColoredLabel(C.REQUEST_PRIORITY, COLOR_REQ_MIN)
        }),
        Pr({ type = "flow", horizontal_align = "center", width = 76 }, {
          ColoredLabel(C.SUPPLY_PRIORITY, COLOR_SUP_MIN)
        })
      }),

      HF({ vertical_align = "center", bottom_margin = 4 }, {
        Pr({ type = "empty-widget", width = 36 }),
        Pr({ type = "flow", horizontal_align = "center", width = 36 }, {
          ColoredLabel(C.MIN_PRIORITY, COLOR_REQ_MIN)
        }),
        Pr({ type = "flow", horizontal_align = "center", width = 36 }, {
          ColoredLabel(C.MAX_PRIORITY, COLOR_REQ_MAX)
        }),
        Pr({ type = "flow", horizontal_align = "center", width = 36 }, {
          ColoredLabel(C.MIN_PRIORITY, COLOR_SUP_MIN)
        }),
        Pr({ type = "flow", horizontal_align = "center", width = 36 }, {
          ColoredLabel(C.MAX_PRIORITY, COLOR_SUP_MAX)
        })
      }),

      Pr({
        type = "scroll-pane",
        style = "scroll_pane",
        direction = "vertical",
        vertical_scroll_policy = "auto",
        horizontal_scroll_policy = "never",
        maximal_height = 200,
        horizontally_stretchable = true
      }, {
        Pr({
          type = "table",
          column_count = 5,
          style = "slot_table"
        }, buildPriorityTableCells(signalPriorities))
      })
    })
  end
})
