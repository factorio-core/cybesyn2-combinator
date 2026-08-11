local constants = require "scripts.constants"
local data_util = require "__cybersyn2-combinator__.lib.core.data-util"

if mods["cybersyn2"] and data.raw.technology["cybersyn2-train-network"] then
  data_util.unlock_recipe_with_technology(constants.ENTITY_NAME, "cybersyn2-train-network")
elseif mods["cybersyn"] and data.raw.technology["cybersyn-train-network"] then
  data_util.unlock_recipe_with_technology(constants.ENTITY_NAME, "cybersyn-train-network")
else
  data_util.unlock_recipe_with_technology(constants.ENTITY_NAME, "circuit-network")
end
