# Planet building scenes

Each scene holds all data for one planet building. Open any `.tscn` (e.g. `ore_mine.tscn`) to edit it in one place:

- Select the root node and expand **Definition** in the Inspector.
- Edit **Identity**: id, name_key, description (what the building does).
- Edit **Cost**, **Jobs**, **Upkeep**, **Slots** (building_slots, slot_type, district_type), and **Display** (icon_path).
- The scene's TextureRect shows the building art when `icon_path` is set.

The definition is stored inside the scene file (sub_resource). Colony loads building defs from these scenes at runtime. The `data/planet_buildings/*.tres` files are only used as fallback if no scene dir is present.
