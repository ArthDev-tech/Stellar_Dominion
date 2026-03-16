# District scenes

Each scene holds all data for one district type. Open any `.tscn` (e.g. `city.tscn`) to edit it in one place:

- Select the root node and expand **Definition** in the Inspector.
- Edit **Identity**: id, name_key, description (what the district does).
- Edit **Cost**, **Jobs**, **Housing**, and **Display** (icon_path).
- The scene's TextureRect shows the district art when `icon_path` is set.

The definition is stored inside the scene file (sub_resource). Colony loads district defs from these scenes at runtime. The `data/planet_districts/*.tres` files are only used as fallback if no scene dir is present.
