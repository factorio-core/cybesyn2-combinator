require "util"
local event = require("__cybersyn2-combinator__/lib/core/event")
local relm = require("__cybersyn2-combinator__/lib/core/relm/relm")

local gui = require "scripts.gui"
local utils = require "scripts.gui.utils"
local C2CC = require "scripts.models.combinator"

relm.bootstrap_with_core_events(event)
gui:init()

--- Reopen combinator GUIs after save/load.
local function reopen_guis_after_load(player_index)
  if not storage.opened_info then return end
  if player_index then
    local info = storage.opened_info[player_index]
    if info and info.entity and info.entity.valid then
      gui:open(player_index, info.entity)
    end
  else
    for pi, info in pairs(storage.opened_info) do
      if info.entity and info.entity.valid then
        gui:open(pi, info.entity)
      end
    end
  end
end

event.bind(defines.events.on_singleplayer_init, function() reopen_guis_after_load(nil) end)
event.bind(defines.events.on_player_joined_game, function(ev) reopen_guis_after_load(ev.player_index) end)

local function handle_entity_built_or_revived(ev)
  local new_entity = ev and (ev.entity or ev.created_entity)
  if not new_entity or not new_entity.valid or not utils.is_combinator_entity(new_entity) then return end

  local comb = C2CC:New(new_entity)
  local tags = ev.tags
  comb:InitializeDefaults(tags and tags.from_blueprint or false, ev.player_index)

  --- Reopen GUI at the same position (blueprint, fast-replace, robot construction).
  if storage.opened_info then
    for player_index, info in pairs(storage.opened_info) do
      if info and info.position and info.surface_index == new_entity.surface.index then
        if math.abs(info.position.x - new_entity.position.x) < 0.01
            and math.abs(info.position.y - new_entity.position.y) < 0.01 then
          gui:open(player_index, new_entity)
        end
      end
    end
  end
end

event.bind(defines.events.on_built_entity, handle_entity_built_or_revived)
event.bind(defines.events.on_robot_built_entity, handle_entity_built_or_revived)
event.bind(defines.events.on_post_entity_died, handle_entity_built_or_revived)
event.bind(defines.events.script_raised_revive, handle_entity_built_or_revived)
event.bind(defines.events.script_raised_built, handle_entity_built_or_revived)

---Close GUI when combinator is mined or destroyed.
local function check_and_close_invalid_guis(ev)
  if not storage.opened_info then return end
  local mined_entity = ev and (ev.entity or ev.created_entity)
  for player_index, info in pairs(storage.opened_info) do
    if not info.entity or not info.entity.valid or (mined_entity and mined_entity == info.entity) then
      gui:close(player_index)
    end
  end
end

event.bind(defines.events.on_player_mined_entity, check_and_close_invalid_guis)
event.bind(defines.events.on_robot_mined_entity, check_and_close_invalid_guis)
event.bind(defines.events.on_entity_died, check_and_close_invalid_guis)
event.bind(defines.events.script_raised_destroy, check_and_close_invalid_guis)

event.bind(defines.events.on_entity_settings_pasted, function(ev)
  local src = ev.source
  local dest = ev.destination
  if src and src.valid and dest and dest.valid and utils.is_combinator_entity(dest) then
    local dest_comb = C2CC:New(dest)
    if utils.is_combinator_entity(src) then
      local src_comb = C2CC:New(src)
      if dest_comb and src_comb then
        dest_comb:CopyFrom(src_comb)
      end
    else
      dest_comb:FixPastedVanillaSections(ev.player_index)
    end
    local player = game.get_player(ev.player_index)
    if player and player.opened and player.opened.valid and player.opened.name == "C2CC.Main" then
      gui:open(ev.player_index, dest)
    end
  end
end)
