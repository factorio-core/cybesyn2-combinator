local mod_name = "cybersyn2-combinator"
local constants = {
  SETTINGS = {
    NEGATIVE_SIGNALS = mod_name .. "-setting-negative-signals",
    DEFAULT_NEGATIVE_SIGNALS = true,
    PRIORITY = mod_name .. "-setting-priority",
    DEFAULT_PRIORITY = 10,
    NETWORK_FLAG = mod_name .. "-setting-network-flag",
    DEFAULT_NETWORK_FLAG = 1,
    STACKS = mod_name .. "-setting-stacks",
    DEFAULT_STACKS = 0,
    COUNT = mod_name .. "-setting-count",
    DEFAULT_COUNT = 0,
    CS_PRIORITY_NAME = "cybersyn2-priority",
  },
  ENTITY_NAME = "cybersyn2-constant-combinator",
  EVENTS = {
    ON_INITIALIZED = mod_name .. "-on_initialized",
    ON_STATUS = mod_name .. "-on_status",
    ON_TAGS_CHANGED = mod_name .. "-on_tags_changed",
  },
}

return constants
