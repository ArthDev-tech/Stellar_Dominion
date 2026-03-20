# Technology Cards — Template and Guide

Use the template and steps below to add new technologies with tiers 1–15 and set up prerequisites easily.

## Template

Copy the object from **tech_entry_template.json** into **techs.json** (inside the top-level array), then edit the fields.

### Field reference

| Field | Type | Description |
|-------|------|-------------|
| **id** | string | Unique identifier. Must match the card scene filename (e.g. `tech_my_tech`). |
| **name_key** | string | Display name shown on the card and in the tree. |
| **category** | number | Branch: `0` = Physical Sciences, `1` = Social Sciences, `2` = Xenological Sciences. |
| **tier** | number | Tier 1–15. Affects card border color and tier gating (need 2 techs of previous tier in same branch to see higher tiers). |
| **cost** | number | Research points (RP) required to complete the tech. |
| **prerequisites** | array of strings | Tech **ids** that must be researched first. Use the Tech IDs reference below when editing. Example: `["tech_basic_energy", "tech_computers_1"]`. |
| **description** | string | Optional. Shown on the card; omit or leave empty for "No description." |
| **unlocks** | array of strings | Optional. Keys for buildings, strategic resources, or other unlocks. |
| **card_scene** | string | Optional. Path to a custom card scene. Omit to use the default `res://ui/components/tech_card.tscn`. Use `res://ui/tech_tree/technology_cards/<branch>/tier_<N>/tech_<id>.tscn`. |

### Prerequisites (requirements)

- **prerequisites** is an array of tech **id** values (the `id` field of other techs).
- List every tech that must be researched before this one. Order in the array does not matter for unlock logic.
- For no requirements use `[]`.
- To pick ids, use the Tech IDs reference below or run **tools/print_tech_ids.gd** (see Tools) to print all ids by branch and tier.

## Steps to add a new tech

1. **Copy the template** from `data/tech_entry_template.json` into `data/techs.json` (add a new object to the array; add a comma after the previous object).
2. **Edit the new object**: set `id`, `name_key`, `category`, `tier`, `cost`, and `prerequisites` (use the Tech IDs reference or print script). Add `description` and `unlocks` if needed.
3. **Card scene (optional)**  
   - Duplicate an existing card scene from `ui/tech_tree/technology_cards/<branch>/tier_<N>/` (e.g. duplicate `tech_basic_energy.tscn`), rename to `tech_<id>.tscn`, and place it in the correct `physical`, `social`, or `xenological` folder under `tier_<N>/`.  
   - Or use the shared **tech_card_template.tscn**: duplicate it, rename to `tech_<id>.tscn`, and move to `ui/tech_tree/technology_cards/<branch>/tier_<N>/`.  
   - Set `card_scene` in the JSON to that path (e.g. `res://ui/tech_tree/technology_cards/physical/tier_3/tech_my_tech.tscn`). If you omit `card_scene`, the default card is used.
4. **Tech tree layout**  
   - If you use the visual tech tree scene (`ui/tech_tree/technology_cards/tech_tree.tscn`), add a node for the new tech (instance your card scene, name it the same as `id`) and place it.  
   - Add connection lines: on the **LinesLayer** node, add entries to **Extra Connections** in the Inspector, each in the form `from_tech_id|to_tech_id` (e.g. `tech_basic_energy|tech_my_tech`).

## Tech IDs reference (for prerequisites)

Use these ids in the `prerequisites` array. Run `tools/print_tech_ids.gd` from the editor or command line to regenerate a list from the current techs.json.

**Physical (category 0):**  
tech_basic_energy, tech_lasers_1, tech_computers_1, tech_reactor_1, tech_advanced_energy, tech_lasers_2, tech_computers_2, tech_research_lab_2, tech_sensors_1, tech_shield_1, tech_particle_lasers, tech_shield_2, tech_exotic_gas_refining, tech_dark_matter_refining, tech_reactor_2, tech_dark_matter_reactor

**Social (category 1):**  
tech_mining_1, tech_alloy_1, tech_armor_1, tech_mass_drivers, tech_mining_2, tech_alloy_2, tech_volatile_mote_refining, tech_mining_3, tech_rare_crystal_refining, tech_megastructure_theory, tech_living_metal_refining, tech_advanced_alloys, tech_mega_engineering

**Xenological (category 2):**  
tech_farming_1, tech_admin_capacity, tech_colonial_centralization, tech_farming_2, tech_gene_clinics, tech_diplomacy_1, tech_habitability_1, tech_trade_policy, tech_galactic_bureaucracy, tech_arcology_project

**See also:** [TECHNOLOGIES.md](TECHNOLOGIES.md) — full list of all technologies with names and descriptions, grouped by tree and tier. Regenerate with `python tools/gen_technologies_md.py`.

## Tools

- **print_tech_ids.gd** — Run from Godot (Editor → Run or open as script and run). Loads `data/techs.json` and prints all tech ids grouped by branch (and tier) so you can copy-paste into `prerequisites`.
- **parse_techtree_md.py** — Parses the expanded tech tree markdown (e.g. `stellar_dominion_techtree_v2.md`) and writes `data/techs.json`. Run from project root: `python tools/parse_techtree_md.py [path/to/techtree.md]`. Default input: `data/stellar_dominion_techtree_v2.md` or `~/Downloads/stellar_dominion_techtree_v2.md`.
- **gen_tech_tree_scene.py** — Updates `ui/tech_tree/technology_cards/tech_tree.tscn` with all techs from `techs.json` (card nodes and layout). Run from project root: `python tools/gen_tech_tree_scene.py`. Run after updating `techs.json`.
- **gen_technologies_md.py** — Generates `data/TECHNOLOGIES.md` from `techs.json` (all techs with names and descriptions by tree and tier). Run from project root: `python tools/gen_technologies_md.py`.
