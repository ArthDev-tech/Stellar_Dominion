# Economy Master — Findings Summary (before writing economy_master.json)

## 1. Buildings (30) — fields present vs missing

| # | Building ID | Has: id, name_key, jobs, cost, building_slots | Missing |
|---|-------------|----------------------------------------------|--------|
| 1 | capital | jobs (ruler, enforcer), cost empty, slots 0 | tier, category, upkeep, tech_required, planet_modifier, description |
| 2 | planetary_authority | jobs (ruler, enforcer), cost empty, slots 0 | tier, category, upkeep, tech_required, planet_modifier, description |
| 3 | planetary_science_complex | jobs (researcher), cost 0/1, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 4 | research_lab | jobs (researcher), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 5 | alloy_foundry | jobs (metallurgist), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 6 | civilian_industries | jobs (artisan), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 7 | orbital_station | jobs (technician, clerk), cost, slots 1, slot_type, station_module, icon | tier, category, upkeep, tech_required, planet_modifier, description |
| 8 | small_shipyard | jobs (metallurgist), cost, slots 1, slot_type, station_module, icon | tier, category, upkeep, tech_required, planet_modifier, description |
| 9 | medium_shipyard | jobs (metallurgist), cost, slots 1, slot_type, station_module, icon | tier, category, upkeep, tech_required, planet_modifier, description |
| 10 | energy_amplifier | jobs {}, cost, slot_type district_amplifier, district_type energy | tier, category, upkeep, building_slots, tech_required, planet_modifier, description |
| 11 | mining_amplifier | jobs {}, cost, slot_type district_amplifier, district_type mining | tier, category, upkeep, building_slots, tech_required, planet_modifier, description |
| 12 | farming_amplifier | jobs {}, cost, slot_type district_amplifier, district_type farming | tier, category, upkeep, building_slots, tech_required, planet_modifier, description |
| 13 | ore_mine | jobs (miner), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 14 | gas_harvester | jobs (technician), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 15 | ice_extractor | jobs (technician, farmer), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 16 | biomass_farm | jobs (farmer), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 17 | fuel_cell_plant | jobs (technician), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 18 | synthetic_fabricator | jobs (artisan), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 19 | pharmaceutical_lab | jobs (chemist), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 20 | consumer_goods_factory | jobs (artisan), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 21 | power_plant | jobs (technician), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 22 | trade_hub | jobs (clerk), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 23 | physical_research_institute | jobs (researcher), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 24 | social_research_centre | jobs (researcher), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 25 | xenological_institute | jobs (researcher), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 26 | housing_complex | jobs (clerk), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 27 | amenities_complex | jobs (clerk), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 28 | unity_monument | jobs (acolyte), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 29 | army_barracks | jobs (soldier), cost, slots 1 | tier, category, upkeep, tech_required, planet_modifier, description |
| 30 | defense_platform | jobs (technician, soldier), cost, slots 1, slot_type orbital, station_module | tier, category, upkeep, tech_required, planet_modifier, description |

**Summary:** All 30 buildings lack tier, category, upkeep, tech_required, planet_modifier in data; description exists only in some .tres files (e.g. ore_mine, capital).

---

## 2. Resources

**From data/resources.json (15):** Energy, Minerals, Food, Alloys, Research, Consumer Goods, Influence, Unity, Trade, Volatile Motes, Exotic Gases, Rare Crystals, Super Tensiles, Dark Matter, Zro. Each has: id (numeric), name_key, short, category (basic/advanced/research/empire/trade/strategic), display_order. **Missing:** description, recipe.

**GDD canonical list (from economy/game_resources.gd):** Raw: Ore (Minerals), Gas, Ice, Biomass. Refined: Alloys, Fuel Cells, Synthetics, Pharmaceuticals, Consumer Goods; Food. Strategic: Volatile Motes, Exotic Gases, Rare Crystals, Super Tensiles, Dark Matter, Zro, Stellite, Void Gas, Nanite Dust, Psionic Ore, Dark Lattice. Abstract: Energy (Energy Credits), Influence, Unity, Research, Trade, Command Points, Cognition, Manpower. RESOURCE_DESCRIPTIONS in game_resources.gd provides description text for all.

---

## 3. Jobs — referenced in buildings vs defined in code

**Referenced in buildings.json:** ruler, enforcer, researcher, metallurgist, artisan, technician, clerk, miner, farmer, chemist, acolyte, soldier.

**Defined in JobType enum (buildings/jobs/job_type.gd):** MINER, GAS_TECHNICIAN, FARMER, METALLURGIST, FUEL_ENGINEER, FABRICATOR, CHEMIST, MANUFACTURER, REACTOR_OPERATOR, TRADE_BROKER, PHYSICIST, SOCIOLOGIST, XENOLOGIST, ADMINISTRATOR, CULTURAL_WORKER, SHIPWRIGHT, GARRISON, SOLDIER, CRYSTAL_HANDLER, NANITE_WARDEN, VOID_ENGINEER, COMPUTRONIUM_ARCHITECT, COGNITE_RESEARCHER.

**Gaps:**
- **Buildings use but enum has no direct match:** ruler → map to ADMINISTRATOR for role; enforcer → GARRISON; acolyte → CULTURAL_WORKER. Master will keep building job ids (ruler, enforcer, acolyte) as the job ids used in job_slots.
- **Buildings use generic names:** researcher (enum has PHYSICIST, SOCIOLOGIST, XENOLOGIST); artisan (enum has MANUFACTURER, FABRICATOR); technician (enum has REACTOR_OPERATOR, GAS_TECHNICIAN); clerk (enum has TRADE_BROKER). Master will include both: building-facing ids (researcher, artisan, technician, clerk) and enum-derived ids (physicist, sociologist, xenologist, etc.).
- **Jobs in enum but not in any building:** gas_technician, fuel_engineer, fabricator, manufacturer, reactor_operator, trade_broker, physicist, sociologist, xenologist, administrator, cultural_worker, shipwright, garrison, crystal_handler, nanite_warden, void_engineer, computronium_architect, cognite_researcher. These get required_building null and placeholder balance where needed.

---

## Final summary (after writing data/economy_master.json)

- **Total buildings:** 30
- **Total jobs:** 30
- **Total resources:** 29
- **Entries with `"placeholder": true`:** 49 (19 jobs + 30 buildings; 0 resources)
