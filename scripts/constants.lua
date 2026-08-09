local constants = {
  SETTINGS = {
    DEFAULT_NEGATIVE_SIGNALS = true,
    DEFAULT_PRIORITY = 10,
    DEFAULT_NETWORK_FLAG = 1,
    DEFAULT_STACKS = 0,
    DEFAULT_COUNT = 0,
    DEFAULT_INPUT_MODE = "count",
    DEFAULT_NETWORK_SIGNAL = { type = "virtual", name = "signal-A" },
    CS_PRIORITY_NAME = "cybersyn2-priority",
  },
  ENTITY_NAME = "cybersyn2-constant-combinator",
  GUI = {
    MAIN_ELEMENT_NAME = "C2CC.Main",
    SECTION_GROUP_ELEMENT_NAME = "C2CC.SectionGroup",
    ENCODER_DIALOG_ELEMENT_NAME = "C2CC.EncoderDialog",
    NETWORKS_DIALOG_ELEMENT_NAME = "C2CC.NetworksDialog",
    SETTINGS_TAB_ELEMENT_NAME = "C2CC.SettingsTab",
    FIELD_EDIT_STACKS = "c2cc_edit_stacks",
    FIELD_EDIT_COUNT = "c2cc_edit_count",
    FIELD_RENAME_GROUP_INPUT = "c2cc_rename_group_input",
    GROUPS_SCROLL_PANE = "c2cc_groups_scroll",
  },
  SECTIONS = {
    CYBERSYN_PRIORITY = 1,
    NETWORK_MASK = 2,
  },
  INPUT_MODE = {
    COUNT = "count",
    STACKS = "stacks",
  },
}

return constants
