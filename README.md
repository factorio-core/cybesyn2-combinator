# Cybersyn 2 Constant Combinator

A specialized constant combinator mod for **Project Cybersyn 2** in Factorio 2.0+.
Provides a clean, reactive Relm user interface for managing station priorities, 32-bit network bitmasks, item/stack quantity calculations, and section group requests directly on native Factorio control behavior sections.

---

## 🌟 Features

- **Cybersyn 2 Control Panel**:
  - Convenient status toggle (`Output: On` / `Output: Off`) and 40-slot output signal grid.
  - Tabbed GUI navigation (**Combinator** and **Settings** tabs).

- **Structured Logistic Sections**:
  - **Section 1**: Station Priority (`cybersyn2-priority` virtual signal).
  - **Section 2**: Network Mask (`signal-A` / customized network signal).
  - **Sections 3+**: Custom section groups for Cybersyn item and fluid requests.
  - Automatic migration script reorganizes existing combinators from older saves.

- **Station Priority & Live Signal Priorities Summary**:
  - Adjust station priority directly in the GUI with automatic pre-filled defaults.
  - **Live Signal Priorities Panel**: Displays an integrated summary pane showing all unique items/fluids at the station with their Min/Max **Request** and **Supply** priorities across matching networks. Tooltips on hover replace column headers for a cleaner look, with auto-scroll and highlight for the selected signal.

- **Network Masks & Bitmask Encoder**:
  - Select network mask signals and edit bitmasks with an interactive 32-bit bitmask encoder.
  - Quick-select active network masks used across your factory from the global network scanner.

- **Item & Stack Request Handling**:
  - Dual independent input fields for **Stacks** and **Count**.
  - **Item Signals**: Selecting an item signal focuses the preferred input mode (**Counts** or **Stacks**) while keeping both fields editable.
  - **Fluid & Virtual Signals**: Automatically focuses **Count** and disables **Stacks**.
  - **Smart Quantity Defaults**: When adding a new signal, automatically defaults to **1 item/fluid** in Counts mode or **1 full stack** in Stacks mode if default quantities are unset (0).
  - **Slot Controls**:
    - **Left-Click empty slot**: Opens the signal picker dialog.
    - **Left-Click filled slot**: Selects the slot and focuses the input field.
    - **Right-Click filled slot**: Clears the signal filter from the slot.

- **In-Game Per-Player Settings**:
  - Full configuration panel embedded directly inside the combinator window (**Settings** tab).
  - Draft state management with **Save** and **Cancel** buttons.
  - **Admin-Only World Batch Updates**: Option to apply default priority or network mask changes across existing combinators on all factory surfaces.

---

## ⚙️ Signal Input Behavior

Behavior of the **Stacks** and **Count** input fields depends deterministically on the selected **Signal Type**:

| Signal Type | **Stacks** Input | **Count** Input | Default Focus | Output Quantity Formula |
| :--- | :--- | :--- | :--- | :--- |
| **Item** (Stackable) | Enabled | Enabled | Preferred Mode (**Counts** / **Stacks**) | `stacks × stack_size` (or exact `count`) |
| **Fluid / Virtual** (Non-stackable) | **Disabled** | Enabled | **Count** | Exact `count` |
| **None** (Empty Slot) | Enabled | Enabled | Preferred Mode | Default setting value (or 1 / 1 stack) |

> **Default Fallback**: If neither input field contains a value when selecting a signal, it automatically uses your configured **Default Output Stacks** or **Default Output Count** setting (or **1 stack** / **1 item** if no default settings are specified).

> **Note**: If the _Negative Signals_ setting is enabled (default), calculated values are automatically converted to negative numbers for Cybersyn 2 request signals.

---

## ⚙️ In-Game Settings (Settings Tab)

Per-player preferences are managed directly in-game via the **Settings** tab in the combinator window:

| Setting | Default | Description |
| :--- | :--- | :--- |
| **Automatically make output signals negative** | `true` | Outputs item and fluid requests as negative values for Cybersyn 2. |
| **Default Station Priority** | `10` | Default priority assigned to new combinators. |
| **Default Network Signal** | `signal-A` | Default network mask signal prototype (e.g. `signal-A`, `signal-B`). |
| **Default Network Mask** | `1` | Default network bitmask flag for new stations. |
| **Default Output Stacks** | `0` | Default stack input value pre-filled in the GUI (0 for 1 stack fallback). |
| **Default Output Count** | `0` | Default count input value pre-filled in the GUI (0 for 1 item fallback). |
| **Default Item Input Mode** | `"count"` | Preferred default focused input field for items (`"count"` or `"stacks"`). |

### Admin Batch Update Options:
- **`Apply priority to all combinators (Admin only)`**: When enabled on Save, updates existing combinators in the world matching previous default priority.
- **`Apply network to all combinators (Admin only)`**: When enabled on Save, updates existing combinators in the world matching previous default network signal and mask.
