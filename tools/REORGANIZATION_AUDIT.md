# Reorganization Audit Report

Post-reorganization audit of UI signal connections, script paths, and autoloads. **Investigation only** — no fixes applied in this audit.

---

## 1. Broken or missing signal connections (Step 1)

None of the 11 audited scenes contain any `[connection]` entries. Every `Button` and `BaseButton` relies on script code (e.g. in `_ready()`) to connect `pressed()` to handlers. If a script failed to load (e.g. wrong path) or node paths in script do not match the scene tree, those runtime connections are never made and buttons do not respond.

**Buttons with no scene-defined `pressed()` connection:**

| Scene | Buttons |
|-------|---------|
| `ui/overlays/colonies_overlay.tscn` | CloseButton |
| `ui/overlays/leaders_overlay.tscn` | CloseButton, RecruitButton |
| `ui/overlays/technology_overlay.tscn` | CloseButton, Tech1Btn, Tech2Btn, Tech3Btn |
| `ui/overlays/fleet_panel.tscn` | CloseButton (parent DraggablePanel connects via script) |
| `ui/panels/ship_designer_window.tscn` | CloseButton, NewDesignButton, SaveDesignButton, DeleteDesignButton |
| `ui/panels/space_station_window.tscn` | CloseButton |
| `ui/panels/build_options_window.tscn` | (no Button nodes; options added dynamically) |
| `ui/panels/planet_view.tscn` | BackButton |
| `ui/tech_tree/tech_tree_overlay.tscn` | CloseButton, ResearchButton, QueueButton |
| `scenes/main/main_menu.tscn` | NewGameButton, QuickStartButton, QuitButton |
| `scenes/galaxy/game_scene.tscn` | PauseButton, CloseButton (SelectedPanel), ViewSystemButton, SurveyButton, ManageColonyButton, ManageStationButton, Tech1Btn, Tech2Btn, Tech3Btn, GalaxyMapButton, PlanetsButton, TechnologyButton, TechTreeButton, LeadersButton, ShipDesignerButton |

---

## 2. Outdated script paths (Step 2)

All `[ext_resource]` script paths in the 11 audited `.tscn` files point to **current** locations (`res://ui/...`, `res://scenes/galaxy/...`, `res://scenes/main/...`).

**Outdated paths found:** None.

No references to `res://scenes/ui/`, `res://scripts/ui/`, or `res://scenes/empire/` remain in these scenes.

---

## 3. Broken autoload paths (Step 3)

Every autoload entry in `project.godot` was checked; each referenced file exists at the listed path.

**Broken autoload paths:** None.

| Autoload | Path | Status |
|----------|------|--------|
| DebugLogger | `res://core/debug_logger.gd` | Exists |
| GameState | `res://core/game_state.gd` | Exists |
| GalaxyManager | `res://core/galaxy_manager.gd` | Exists |
| EmpireManager | `res://empire/empire_manager.gd` | Exists |
| EconomyManager | `res://economy/economy_manager.gd` | Exists |
| ShipDesignManager | `res://ships/ship_design_manager.gd` | Exists |
| ResearchManager | `res://empire/research_manager.gd` | Exists |
| LeaderManager | `res://leaders/leader_manager.gd` | Exists |
| CouncilManager | `res://leaders/council/council_manager.gd` | Exists |
| PrecursorManager | `res://galaxy/scripts/precursor_manager.gd` | Exists |
| ProjectPaths | `res://core/project_paths.gd` | Exists |
| EventBus | `res://core/event_bus.gd` | Exists |
| JobAssignmentManager | `res://buildings/jobs/job_assignment_manager.gd` | Exists |
| SelectionManager | `res://core/selection_manager.gd` | Exists |

---

## 4. Recommended fix order

1. **Signal/connection fixes first**  
   Ensure every button either has a scene-defined `pressed()` connection or a valid in-script connection with correct node paths. Verify that scripts load (no missing or wrong script paths) and that `@onready` / `get_node` paths match the actual scene tree in each audited scene.

2. **Re-verify**  
   Run the game and confirm buttons respond; use `DebugLogger` (first autoload) to confirm "Button pressed" messages when clicking.

3. **Autoload path fixes**  
   Not required; all autoload paths already resolve to existing files.

---

## 5. DebugLogger autoload

- **File:** `core/debug_logger.gd`  
- **Registration:** First autoload in `project.godot` as `DebugLogger`  
- **Behavior:** Prints init message, subscribes to `node_added`/`node_removed`, connects to every new Button/BaseButton `pressed` and logs "Button pressed: &lt;path&gt;", and provides `log_info` / `log_error` for other systems.
