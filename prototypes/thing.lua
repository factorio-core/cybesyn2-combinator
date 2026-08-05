local constants = require("scripts.constants")
local things = require("__0-things__.client.client")

things.register({
  name = constants.ENTITY_NAME,
  custom_events = {
    on_initialized = constants.EVENTS.ON_INITIALIZED,
    on_status = constants.EVENTS.ON_STATUS,
    on_tags_changed = constants.EVENTS.ON_TAGS_CHANGED,
  },
})

data:extend({
  { type = "custom-event", name = constants.EVENTS.ON_INITIALIZED },
  { type = "custom-event", name = constants.EVENTS.ON_STATUS },
  { type = "custom-event", name = constants.EVENTS.ON_TAGS_CHANGED },
})
