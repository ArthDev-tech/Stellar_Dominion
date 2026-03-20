# Ship selection audit — findings before fixes

## AUDIT A — New ship registration

### (a) Where new ships are created at runtime
- **economy/economy_manager.gd** — `_process_ship_build_queues()` (or similar): when a build completes, `Ship.new(empire.id, station.system_id, design_id, name_key)` and `empire.ships.append(ship)`; then `ship_built.emit(station.system_id)`.
- **empire/empire_manager.gd** — game start / empire setup: loop over `starting_designs`, `Ship.new(empire.id, system_id, design.id, design.name)` and `empire.ships.append(ship)`.
- No debug spawn or other creation sites found.

### (b) Are ship_galaxy_icon nodes created at creation sites?
**No.** Neither economy_manager nor empire_manager creates any icon or node. Icons are created only in **scenes/galaxy/game_scene.gd** in `_refresh_galaxy_ship_nodes()`, which:
- Iterates `player_emp.ships` (idle ships, then in_hyperlane ships),
- For each ship creates a `Node2D`, sets script to `ship_galaxy_icon.gd`, calls `setup_galaxy_ship(s)`, adds to `ships_layer`.

So newly built ships get an icon only when `_refresh_galaxy_ship_nodes()` runs. That is triggered by:
- Layout signature change in `_process` (`_refresh_galaxy_ship_nodes_if_layout_changed()`),
- Or the existing `_on_ship_built_galaxy()` handler that invalidates the layout sig and calls the same refresh.

If refresh does not run in the same frame or before the next input, new ships can momentarily have no icon and be unselectable.

### (c) How ship_galaxy_icon registers with selection
Icons do **not** register with SelectionManager or the selection handler via a signal or method. **scenes/galaxy/ship_galaxy_icon.gd** `_ready()` only:
- Sets `z_index = 2`
- Calls `add_to_group("galaxy_ship_icons")`
- Creates the path Line2D child.

Selection works because **scenes/galaxy/galaxy_selection_handler.gd** uses `get_tree().get_nodes_in_group("galaxy_ship_icons")` for both click and box selection and tests screen/world position. So any node in the tree that is in the group is selectable. There is no explicit “register ship icon” call; the only requirement is that the icon exists in the tree and is in the group when the user clicks or drags.

### (d) input_pickable / mouse_filter
**ship_galaxy_icon** extends **Node2D**. Node2D has no `mouse_filter` (that is on Control) and no `input_pickable` (that is on Area2D). Clicks are not delivered to the icon; the selection handler receives the LMB release, converts to world position, and finds the nearest node in `galaxy_ship_icons` within CLICK_RADIUS. So `input_pickable` and `mouse_filter` do not apply; game-start and newly built icons behave the same (no per-node input).

### (e) z_index
In **ship_galaxy_icon.gd** `_ready()`, `z_index = 2` is set for every icon. Game-start and newly built icons use the same script and same _ready(), so z_index is identical.

### (f) Parent node
In **game_scene.gd** `_refresh_galaxy_ship_nodes()`, every icon is added with `ships_layer.add_child(node)`. Both game-start ships and newly built ships (after refresh) are children of **ships_layer** (under GalaxyMap). No icons are added as children of a star system node; coordinate space and parent are the same for all.

---

## AUDIT B — Stale selection on galaxy map return

### (a) What SelectionManager.selected_ships contains when galaxy map becomes visible
SelectionManager is an autoload; `selected_ships` persists across scene changes. When returning from system view, `close_embedded_solar_system()` calls `_refresh_galaxy_ship_nodes()` then `SelectionManager.refresh_after_galaxy_ship_rebuild()`, which runs `_highlight_matching_icons()`. So **selected_ships is not cleared** on return; whatever was in it (e.g. ships selected in system view or from a previous action) is re-applied to the newly built icons. If that data is from a **previous game session** (e.g. after “Start new game” from main menu), it can still match new ships by `ship_name` + `galaxy_system_id` + `galaxy_empire_id`, so the ring appears on the wrong ships.

### (b) Every place that calls set_selection() or assigns selected_ships
- **core/selection_manager.gd** — `set_selection(ships_data: Array)` is the only writer to `selected_ships` (it clears and repopulates). No direct assignment to `selected_ships` elsewhere.
- **galaxy_selection_handler.gd** — `_perform_box_select` and `_perform_click_select` call `SelectionManager.set_selection(payload)` or `set_selection(one)` when the user selects ships; `clear_selection()` when click hits empty space.
- **ui/overlays/fleet_panel.gd** — “Deselect all” calls `SelectionManager.set_selection([])`.
- **scenes/galaxy/game_scene.gd** — `SelectionManager.clear_selection()` in `_ready()`; also on ESC and when clicking empty space or selecting a system in `_try_select_system_at()`.
- **scenes/galaxy/solar_system_view.gd** — multiple calls to `set_selection([])` or `set_selection(payload)` on overlay close, system change, or ship selection in system view.

None of these are tied to “galaxy map becomes visible” by a visibility signal; they are tied to user input or explicit UI close.

### (c) SelectionManager._ready() and selected_ships init
**SelectionManager has no _ready().** It declares `var selected_ships: Array[ShipData] = []`, so it starts as an empty array. If the project is run and the game scene is the first scene, that is fine. If the player goes to main menu and then starts a new game, the autoload is not re-created; `selected_ships` keeps the previous run’s contents unless something clears it.

### (d) Auto-selection on galaxy map _ready() or when galaxy map becomes visible
**game_scene.gd** `_ready()` calls `SelectionManager.clear_selection()`, so it does not auto-select. There is no `visibility_changed` or similar on `galaxy_map` that calls `set_selection`. So there is no code that “auto-selects ships when the galaxy map appears.” The bug is that **selection is never cleared when starting a new game** (e.g. from main menu or galaxy setup). So stale `selected_ships` from a previous session is re-applied when the new game’s icons are built and `refresh_after_galaxy_ship_rebuild()` runs.

### (e) Signals in _ready() that fire immediately and trigger selection
None found. `game_scene` connects `ship_built` to `_on_ship_built_galaxy` (refresh only); it does not call `set_selection`. No connection in `galaxy_selection_handler` or game_scene _ready() causes selection to be set on load.

---

## Root causes (concise)
1. **New ships not selectable:** Icons are created only in `_refresh_galaxy_ship_nodes()`. That already runs after `ship_built` (via `_on_ship_built_galaxy`). If there is still a timing or ordering edge case, centralizing icon creation in a single `spawn_ship_icon()` and using an icon registry makes behavior consistent and ensures rubber-band/click only hit registered icons.
2. **Stale selection on galaxy return / game start:** `SelectionManager.selected_ships` is never cleared when starting a new game (`GameState.start_new_game()` did not call `SelectionManager.clear_selection()`). So old ShipData from a previous run can match new ships and make their rings appear selected.

---

## Fixes applied
- **SelectionManager:** `_ready()` clears `selected_ships`. Added `_icon_registry`, `register_ship_icon()`, `unregister_ship_icon()`, `clear_icon_registry()`, `get_registered_icons()`. `_all_icons_galaxy_selected` and `_highlight_matching_icons` use registry with fallback to group.
- **GameState.start_new_game():** Calls `SelectionManager.clear_selection()` and `SelectionManager.clear_icon_registry()`.
- **game_scene:** Added `spawn_ship_icon(ship, position)`; `_refresh_galaxy_ship_nodes()` clears registry, frees old icons, then uses `spawn_ship_icon()` for each ship (idle and in_hyperlane). # AUDIT: NEEDS REVIEW left at both call sites.
- **ship_galaxy_icon._ready():** Explicitly sets `_is_galaxy_selected = false`.
- **galaxy_selection_handler:** `_perform_box_select` and `_perform_click_select` use `SelectionManager.get_registered_icons()` with fallback to `get_nodes_in_group("galaxy_ship_icons")`.
- Ship creation in economy_manager and empire_manager does not create icons (do not touch); icons are created only when `_refresh_galaxy_ship_nodes()` runs.
