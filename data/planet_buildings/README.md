# Planet building definitions

Each `.tres` file is a **PlanetBuildingDefinitionResource** you can edit in the Inspector.

- **Identity**: `id`, `name_key`, `description` (what the building does)
- **Cost**: construction cost (resource type → amount; use GameResources.ResourceType as key)
- **Jobs**: job id (String) → number of slots, e.g. `{ "miner": 2 }`
- **Upkeep**: monthly upkeep (resource type → amount); leave empty if jobs define upkeep
- **Slots**: `building_slots`, `slot_type` ("planetary", "orbital", "district_amplifier"), `district_type` (for amplifiers)
- **Display**: `icon_path` — path to the building art, e.g. `res://assets/buildings/ore_mine.png`

Colony and the planet view load these at runtime. Orbital buildings remain in `data/buildings.json`.
