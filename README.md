# Cybersyn 2 Constant Combinator

A specialized constant combinator mod for **Project Cybersyn 2** in Factorio 2.0+.
Designed to provide a clean and intuitive user interface for managing station priorities, network masks, and output item/fluid requests.

---

## 🌟 Features

- **Cybersyn 2 Control Panel**:
  - Convenient status toggle (`Output: On` / `Output: Off`) and 40-slot output signal grid.

- **Station Priority**:
  - Adjust station priority directly in the GUI.

- **Network Masks & Bitmask Encoder**:
  - Select network mask signals and edit bitmasks with an interactive 32-bit encoder.
  - Quick-select active network masks used across your factory from the global network list.

- **Item & Stack Request Handling**:
  - Dual independent input fields for **Stacks** and **Count**.
  - **Item Signals**: Selecting an item signal automatically focuses **Stacks** while keeping **Count** editable.
  - **Fluid & Virtual Signals**: Selecting a fluid or virtual signal automatically focuses **Count** and disables **Stacks**.
  - **Slot Controls**:
    - **Left-Click empty slot**: Opens the signal picker dialog.
    - **Left-Click filled slot**: Selects the slot and focuses the input field.
    - **Right-Click filled slot**: Clears the signal filter from the slot.

- **Automatic Pre-configuration**:
  - Placed combinators are automatically pre-configured with default priority and network flags upon placement.

---

## ⚙️ Signal Input Behavior

Behavior of the **Stacks** and **Count** input fields depends deterministically on the selected **Signal Type**:

| Signal Type | **Stacks** Input | **Count** Input | Default Focus | Output Quantity Formula |
| :--- | :--- | :--- | :--- | :--- |
| **Item** (Stackable) | Enabled | Enabled | **Stacks** | `stacks × stack_size` (or exact `count`) |
| **Fluid / Virtual** (Non-stackable) | **Disabled** | Enabled | **Count** | Exact `count` |
| **None** (Empty Slot) | Enabled | Enabled | **Stacks** | Default setting value |

> **Default Fallback**: If neither input field contains a value when selecting an item signal, it automatically falls back to your configured **Default Output Stacks** or **Default Output Count** setting (or **1 stack** if no default settings are specified). Fluid requests fall back to 1 unit.

> **Note**: If the _Negative Signals_ setting is enabled (default), calculated values are automatically converted to negative numbers for Cybersyn 2 request signals. Manual negative numbers are fully supported when this setting is disabled.

---

## ⚙️ Mod Settings

Configure default behaviors under _Settings -> Mod settings_:

| Setting | Default | Description |
| :--- | :--- | :--- |
| **Negative Signals** | `true` | Automatically outputs item and fluid requests as negative values for Cybersyn 2. |
| **Default Station Priority** | `10` | Default priority assigned to new combinators. |
| **Default Network Flag** | `1` | Default network bitmask flag for new stations. |
| **Default Output Stacks** | `0` | Default stack input value pre-filled in the GUI (0 for empty). |
| **Default Output Count** | `0` | Default count input value pre-filled in the GUI (0 for empty). |
