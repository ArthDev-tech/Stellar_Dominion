# Selection freeze / "Object was deleted while awaiting a callback" — audit

**Most recent git commit touching these paths:** initial project commit (`2f651e0`); subsequent README-only commit. Selection/fleet logic is unchanged in git since initial import.

## 1(a) Signal connections (selection-related, in scope)

| File | Signal | Emitter | Callable |
|------|--------|---------|----------|
| fleet_panel.gd | ships_selected | EventBus | _on_ships_selected |
| game_scene.gd | selection_changed | SelectionManager | _on_galaxy_ship_selection_route_preview |

**galaxy_selection_handler.gd**: No `.connect()`. It only **emits** `selection_changed(selected_ships)` (after box/click select). Nothing in the audited files connects to the **handler’s** signal; game_scene connects to **SelectionManager.selection_changed**, not the handler.

**ship_galaxy_icon.gd**: No signals, no `.connect()`. Galaxy map ship layer uses **fleet_galaxy_icon.gd** (one node per system fleet), not per-ship icons.

## 1(b) Connections in _process / _physics_process or re-emitting cycle?

- **galaxy_selection_handler.gd**: No _process/_physics_process. No signal handlers.
- **fleet_panel.gd**: `EventBus.ships_selected.connect(_on_ships_selected)` in _ready only. _on_ships_selected does not emit selection signals.
- **ship_galaxy_icon.gd** / **fleet_galaxy_icon.gd**: _process only updates pulse_timer and queue_redraw when selected; no connect.
- **game_scene.gd**: `SelectionManager.selection_changed.connect(_on_galaxy_ship_selection_route_preview)` in _ready only. **Indirect cycle risk:** _process → `_refresh_galaxy_ship_nodes()` → queue_free fleet icons → `SelectionManager.set_selection(to_select)` → emits → `_on_galaxy_ship_selection_route_preview` + FleetPanel. **SelectionManager._process** purges invalid refs and may emit again the next frame if icons were freed while still listed in `selected_ships`.

**Conclusion:** No connect() inside _process. Multiple emissions per session are possible when `selected_ships` holds nodes that become invalid (e.g. around ship layer rebuild).

## 1(c) queue_freed nodes with non–CONNECT_ONE_SHOT connections?

Fleet icons live under `ships_layer` and are queue_freed in `game_scene._refresh_galaxy_ship_nodes()`. No script connects **to** those icon nodes. Risk: **SelectionManager.selected_ships** may still reference icons until cleared/replaced; emitted arrays are duplicates of that list—handlers must use `is_instance_valid` on every element before touching nodes.

## 1(d) ships_selected / selection_changed emitted inside loop over ship nodes?

- **SelectionManager**: Emits once per `set_selection` / `add_to_selection` after loops, with `duplicate()`.
- **galaxy_selection_handler**: Emits once after box/click logic, not inside the node loop; now emits `SelectionManager.selected_ships.duplicate()`.

## 1(e) FleetPanel per-ship connections?

FleetPanel only connects to `EventBus.ships_selected` in _ready. No per–fleet-icon signal connections. `clear_ship_connections()` is called at the start of `_on_ships_selected` for future per-ship wiring.

---

## Root cause (duplicate `galaxy_ships` while queue_freed)

`_refresh_galaxy_ship_nodes` calls `queue_free()` on fleet icons, but those nodes stay in the scene tree (and in group `galaxy_ships`) until end of frame while new icons are added. Box/click select via `get_nodes_in_group("galaxy_ships")` could pick **doomed** icons. `set_selection` then set `selected = true` → `queue_redraw()` on a node queued for deletion → Godot 4.5+ **"Object was deleted while awaiting a callback"** spam/freeze.

**Fix:** `remove_from_group("galaxy_ships")` before `queue_free` on ship-layer children; skip `is_queued_for_deletion()` in the selection handler; SelectionManager only selects nodes that pass `_is_selectable_ship_node()`.

---

## Fixes applied (callback loop hardening)

- **SelectionManager**: `set_selection` / `add_to_selection` only append **valid** instances; emits use `duplicate()`; `_process` purges invalid refs and emits only when the valid set size differs from `selected_ships`.
- **game_scene**: `_refresh_galaxy_ship_nodes` filters `to_select` with `is_instance_valid` before `set_selection`; `_update_route_preview` filters `selected_ships` and returns early if empty.
- **galaxy_selection_handler**: Handler signal emits `SelectionManager.selected_ships.duplicate()`.
- **fleet_panel**: `# AUDIT: NEEDS REVIEW` on `EventBus.ships_selected.connect`; `_on_ships_selected` filters `SelectionManager.selected_ships` with `is_instance_valid` before use.
