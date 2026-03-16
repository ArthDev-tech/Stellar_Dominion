class_name JobType
extends RefCounted
## Enum of all job categories. Display names for UI.

enum Type {
	# Extraction
	MINER,
	GAS_TECHNICIAN,
	FARMER,
	# Refinement & Industry
	METALLURGIST,
	FUEL_ENGINEER,
	FABRICATOR,
	CHEMIST,
	MANUFACTURER,
	# Energy & Trade
	REACTOR_OPERATOR,
	TRADE_BROKER,
	# Research
	PHYSICIST,
	SOCIOLOGIST,
	XENOLOGIST,
	# Population & Social
	ADMINISTRATOR,
	CULTURAL_WORKER,
	# Military
	SHIPWRIGHT,
	GARRISON,
	SOLDIER,
	# Strategic / Exotic
	CRYSTAL_HANDLER,
	NANITE_WARDEN,
	VOID_ENGINEER,
	# Megascale
	COMPUTRONIUM_ARCHITECT,
	COGNITE_RESEARCHER,
}

static func display_name(t: Type) -> String:
	match t:
		Type.MINER: return "Miner"
		Type.GAS_TECHNICIAN: return "Gas Technician"
		Type.FARMER: return "Farmer"
		Type.METALLURGIST: return "Metallurgist"
		Type.FUEL_ENGINEER: return "Fuel Engineer"
		Type.FABRICATOR: return "Fabricator"
		Type.CHEMIST: return "Chemist"
		Type.MANUFACTURER: return "Manufacturer"
		Type.REACTOR_OPERATOR: return "Reactor Operator"
		Type.TRADE_BROKER: return "Trade Broker"
		Type.PHYSICIST: return "Physicist"
		Type.SOCIOLOGIST: return "Sociologist"
		Type.XENOLOGIST: return "Xenologist"
		Type.ADMINISTRATOR: return "Administrator"
		Type.CULTURAL_WORKER: return "Cultural Worker"
		Type.SHIPWRIGHT: return "Shipwright"
		Type.GARRISON: return "Garrison"
		Type.SOLDIER: return "Soldier"
		Type.CRYSTAL_HANDLER: return "Crystal Handler"
		Type.NANITE_WARDEN: return "Nanite Warden"
		Type.VOID_ENGINEER: return "Void Engineer"
		Type.COMPUTRONIUM_ARCHITECT: return "Computronium Architect"
		Type.COGNITE_RESEARCHER: return "Cognite Researcher"
		_: return "Unknown"
