# Audit — Galaxy ship selection (before rebuild)

## (a) Selection ring / highlight parent
- **Star system “selected” ring**: Drawn in `star_system_node.gd` `_draw()` when `GameState.selected_system_id == id` — `draw_arc` on the **star system Node2D** (parent: `SystemsLayer`).
- **Ship selection halo**: Was on **fleet_galaxy_icon** (child of `ShipsLayer`), one blob per system — visually stacked on the star position, easy to confuse with the system.

## (b) Input order on ship click
- **GalaxySelectionHandler** receives LMB via **game_scene._unhandled_input** first on release (after drag).
- Picking uses `get_nodes_in_group("galaxy_ships")` + distance/box — **no separate hit test on star system** for ships; star system has **no input node** (pure `_draw`).
- System selection runs **after** handler returns false (no ship hit). Order: **selection handler → then _try_select_system_at**.

## (c) Ship type tabs (Science/Construction/Military)
- `_on_ship_filter_pressed` sets `_galaxy_ship_filter` and `_galaxy_selected_indicator`, redraws system indicators, calls `_update_selected_panel()`.
- Does **not** call `SelectionManager.set_selection` — but FleetPanel read **SelectionManager.selected_ships as Node list** tied to fleet icons; changing filter redraw relied on fleet nodes — panel could empty when selection state didn’t match **FleetData** aggregation.

## (d) Path preview
- Shared **Line2D** `_route_preview_line` on `RoutePreviewLayer` under `GalaxyMap`.
- **Gated by**: `_find_rep_ship_with_route_for_selection` — needs **FleetData** on selected **nodes** and a live `Ship` with `target_system_id` or `path_queue`. Wrong/missing FleetData on icon broke the preview.

## (e) z_index
- **Star system nodes** and **fleet icons** are siblings under different layers (`SystemsLayer` vs `ShipsLayer`) — draw order is layer order, not z_index on icons. **No raycast** on system; issue was **visual** (ring on star vs ship), not blocking.

## # AUDIT: NEEDS REVIEW
- Ship icons as children of **ShipsLayer** (sibling to SystemsLayer) — z_index on icon is relative to `ShipsLayer` only; systems draw in another layer. If hierarchy changes to children of system node, split star back/front layers per spec.
