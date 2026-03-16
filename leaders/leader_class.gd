class_name LeaderClass
extends RefCounted
## Leader class enum: Commander, Administrator, Scientist, Strategist.

enum Class {
	COMMANDER,
	ADMINISTRATOR,
	SCIENTIST,
	STRATEGIST,
}

static func display_name(c: Class) -> String:
	match c:
		Class.COMMANDER: return "Commander"
		Class.ADMINISTRATOR: return "Administrator"
		Class.SCIENTIST: return "Scientist"
		Class.STRATEGIST: return "Strategist"
		_: return "Unknown"

static func valid_council_positions(c: Class) -> Array:
	match c:
		Class.COMMANDER: return ["high_admiral", "lord_general", "void_sentinel"]
		Class.ADMINISTRATOR: return ["sector_chancellor", "minister_of_state", "trade_overseer"]
		Class.SCIENTIST: return ["head_of_research", "exploration_director", "xenological_minister"]
		Class.STRATEGIST: return ["megaproject_director", "resource_warden", "cascade_monitor"]
		_: return []

static func xp_sources(c: Class) -> Array:
	match c:
		Class.COMMANDER: return ["fleet_combat", "bombardment", "army_assault", "patrol_months"]
		Class.ADMINISTRATOR: return ["planet_governed_months", "pop_growth_events", "trade_route_months"]
		Class.SCIENTIST: return ["survey_complete", "anomaly_resolved", "dig_site_complete", "research_breakthrough"]
		Class.STRATEGIST: return ["megastructure_stage_complete", "strategic_resource_secured", "cascade_prevented"]
		_: return []
