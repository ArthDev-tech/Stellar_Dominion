# District definitions

Each `.tres` file is a **DistrictDefinitionResource** you can edit in the Inspector.

- **Identity**: `id`, `name_key`, `description` (what the district does)
- **Cost**: construction cost (resource type → amount)
- **Jobs**: job id (String) → slots per district, e.g. `{ "technician": 2 }`
- **Housing**: housing provided by one district
- **Display**: `icon_path` — path to the district art

Colony and the planet view load these at runtime.
