extends Node
## Centralized scene and data paths. Add as autoload "ProjectPaths" to change paths in one place.

# Main scenes
const SCENE_MAIN_MENU := "res://scenes/main/main_menu.tscn"
const SCENE_GALAXY_SETUP := "res://scenes/main/galaxy_setup.tscn"
const SCENE_GAME_SCENE := "res://scenes/galaxy/game_scene.tscn"
const SCENE_SOLAR_SYSTEM_VIEW := "res://scenes/galaxy/solar_system_view.tscn"

# Overlay / UI scenes (fallbacks when @export PackedScene is null)
const SCENE_COLONIES_OVERLAY := "res://ui/overlays/colonies_overlay.tscn"
const SCENE_TECHNOLOGY_OVERLAY := "res://ui/overlays/technology_overlay.tscn"
const SCENE_TECH_TREE_OVERLAY := "res://ui/tech_tree/tech_tree_overlay.tscn"
const SCENE_TECH_TREE := "res://ui/tech_tree/technology_cards/tech_tree.tscn"
const SCENE_LEADERS_OVERLAY := "res://ui/overlays/leaders_overlay.tscn"
const SCENE_PLANET_VIEW := "res://ui/panels/planet_view.tscn"
const SCENE_SPACE_STATION_WINDOW := "res://ui/panels/space_station_window.tscn"
const SCENE_SHIP_DESIGNER_WINDOW := "res://ui/panels/ship_designer_window.tscn"

# Data files
const DATA_TECHS := "res://data/techs.json"
const DATA_BUILDINGS := "res://data/buildings.json"
const DATA_DISTRICTS := "res://data/districts.json"
const DATA_CITY_SPECIALIZATIONS := "res://data/city_specializations.json"
const DATA_SHIP_DESIGNS := "res://data/ship_designs.json"
const DATA_SHIP_HULLS := "res://data/ship_hulls.json"
const DATA_SHIP_COMPONENTS := "res://data/ship_components.json"
const DATA_PRECURSORS := "res://data/precursors.json"
const DATA_LEADER_TRAITS := "res://data/leader_traits.json"
const DATA_JOB_BALANCE := "res://data/job_balance.tres"
const DATA_PLANET_BUILDINGS_DIR := "res://data/planet_buildings/"
const DATA_PLANET_DISTRICTS_DIR := "res://data/planet_districts/"
const SCENES_PLANET_BUILDINGS_DIR := "res://scenes/planet/buildings/"
const SCENES_PLANET_DISTRICTS_DIR := "res://scenes/planet/districts/"

# Building scenes (editor-first balancing; each building is an inherited scene)
const BUILDINGS_BASE_SCENE := "res://buildings/scenes/building_base.tscn"
const BUILDINGS_SCENES_EXTRACTION := "res://buildings/scenes/extraction/"
const BUILDINGS_SCENES_REFINEMENT := "res://buildings/scenes/refinement/"
const BUILDINGS_SCENES_ENERGY := "res://buildings/scenes/energy/"
