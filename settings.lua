local constants = require "scripts.constants"
local SETTINGS = constants.SETTINGS

data:extend {
  {
    type = "bool-setting",
    name = SETTINGS.NEGATIVE_SIGNALS,
    setting_type = "runtime-per-user",
    default_value = SETTINGS.DEFAULT_NEGATIVE_SIGNALS,
    order = "c[cybersyn]-c[combinator]-s[signals]-n[negative]"
  },
  {
    type = "int-setting",
    name = SETTINGS.PRIORITY,
    setting_type = "runtime-global",
    default_value = SETTINGS.DEFAULT_PRIORITY,
    minimum_value = -2147483648,
    maximum_value = 2147483647,
    order = "c[cybersyn]-c[combinator]-p[priority]"
  },
  {
    type = "int-setting",
    name = SETTINGS.NETWORK_FLAG,
    setting_type = "runtime-global",
    default_value = SETTINGS.DEFAULT_NETWORK_FLAG,
    minimum_value = -2147483648,
    maximum_value = 2147483647,
    order = "c[cybersyn]-c[combinator]-n[network-flag]"
  },
  {
    type = "int-setting",
    name = SETTINGS.STACKS,
    setting_type = "runtime-per-user",
    default_value = SETTINGS.DEFAULT_STACKS,
    minimum_value = 0,
    maximum_value = 2147483647,
    order = "c[cybersyn]-c[combinator]-s[stacks]"
  },
  {
    type = "int-setting",
    name = SETTINGS.COUNT,
    setting_type = "runtime-per-user",
    default_value = SETTINGS.DEFAULT_COUNT,
    minimum_value = 0,
    maximum_value = 2147483647,
    order = "c[cybersyn]-c[combinator]-s[stacks]-c[count]"
  }
}
