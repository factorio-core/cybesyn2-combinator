local constants = require "scripts.constants"
local strace = require "__0-things__.lib.core.strace"
local things_client = require "__0-things__.client.client"
local cc_gui = require "scripts.gui"

local cc_remote = {}

--- Performs a Breadth-First Search (BFS) over circuit network wires (green/red)
--- to find the nearest Cybersyn 2 combinator from the starting entity.
--- @param entity LuaEntity Starting entity
--- @param max_iterations integer Maximum depth of wire traversal steps
--- @return LuaEntity? Found Cybersyn 2 combinator entity or nil
local function find_combinator(entity, max_iterations)
  if not entity or not entity.valid then return nil end
  --- @type { [uint]: boolean }
  local visited = { [entity.unit_number] = true }
  --- @type LuaEntity[]
  local queue = { entity }
  local head = 1
  local green_i = 0
  local red_i = 0

  while head <= #queue do
    local current = queue[head]
    head = head + 1

    if current.name == constants.ENTITY_NAME then return current end

    local connected = current.circuit_connected_entities
    if not connected then goto continue end

    if green_i <= max_iterations and connected.green then
      for _, child in pairs(connected.green) do
        local id = child.unit_number
        if id and not visited[id] then
          visited[id] = true
          queue[#queue + 1] = child
          green_i = green_i + 1
        end
      end
    end

    if red_i <= max_iterations and connected.red then
      for _, child in pairs(connected.red) do
        local id = child.unit_number
        if id and not visited[id] then
          visited[id] = true
          queue[#queue + 1] = child
          red_i = red_i + 1
        end
      end
    end

    ::continue::
  end

  return nil
end

--- Opens the Cybersyn 2 combinator GUI for a player. If the entity is not a combinator itself,
--- attempts to find the nearest connected combinator over the circuit network.
--- @param player_index uint? Player index
--- @param entity LuaEntity? Selected entity
--- @return boolean success true if a combinator was found and successfully opened
function cc_remote.open(player_index, entity)
  strace.debug("context", "remote", "Remote open called with player index ", player_index)

  if not entity or not entity.valid then return false end
  if entity.type == "entity-ghost" then return false end

  local combinator = find_combinator(entity, 20)

  if not combinator then
    strace.debug("context", "remote", "Could not find entity to open")
    return false
  end

  local thing_id = things_client.get_thing_id(combinator)
  return cc_gui:open(player_index, combinator, thing_id)
end

--- Closes the combinator GUI interface for a player via remote call.
--- @param player_index uint? Player index
function cc_remote.close(player_index)
  strace.debug("context", "remote", "Remote close called with player index ", player_index)
  cc_gui:close(player_index)
end

--- Registers remote interface "cybersyn2-combinator".
function cc_remote:register()
  remote.add_interface("cybersyn2-combinator", {
    open = self.open,
    close = self.close
  })
end

return cc_remote
