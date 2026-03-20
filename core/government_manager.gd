extends Node
## Keys to Power: tracks government type and key holders (voting blocs). Player-only.
## Autoload: GovernmentManager

enum GovernmentType {
	DEMOCRACY,
	OLIGARCHY,
	AUTHORITARIANISM,
	THEOCRACY
}

var current_government_type: GovernmentType = GovernmentType.DEMOCRACY
var active_key_holders: Array[KeyHolder] = []
var policy_levers: Array[PolicyLever] = []
## Categories drive the category-panel UI; rebuilt after policy_levers for current government. Empty categories omitted.
var categories: Array = []

## ConnectionLink: dict with policy_id (StringName), holder_id (StringName), direction (int +1/-1), strength (float).
var connections_by_government: Dictionary = {}  ## GovernmentType -> Array of link dicts

@export_group("Balance")
@export var loyalty_decay_per_unfulfilled: float = 2.0
@export var loyalty_fulfill_bonus: float = 15.0
@export var new_demand_delay_seconds: float = 30.0

var _new_demand_resources: Array[String] = ["Consumer Goods", "Research", "Energy Credits", "Alloys"]
var _new_demand_amounts: Array[int] = [50, 30, 40, 20]


func _ready() -> void:
	_build_connections_by_government()
	rebuild_for_government_type(GovernmentType.DEMOCRACY)


func get_active_connections() -> Array:
	var key := current_government_type
	if not connections_by_government.has(key):
		return []
	return connections_by_government[key]


func get_policy_value(policy_id: StringName) -> float:
	for p in policy_levers:
		if p.id == policy_id:
			return p.value
	return 0.0


func get_policy_lever(policy_id: StringName) -> PolicyLever:
	for p in policy_levers:
		if p.id == policy_id:
			return p
	return null


func rebuild_for_government_type(type: GovernmentType) -> void:
	current_government_type = type
	policy_levers.clear()
	active_key_holders.clear()
	categories.clear()
	match type:
		GovernmentType.DEMOCRACY:
			_build_democracy_policies()
			_build_democracy_key_holders()
		GovernmentType.OLIGARCHY:
			_build_oligarchy_policies()
			_build_oligarchy_key_holders()
		GovernmentType.AUTHORITARIANISM:
			_build_authoritarianism_policies()
			_build_authoritarianism_key_holders()
		GovernmentType.THEOCRACY:
			_build_theocracy_policies()
			_build_theocracy_key_holders()
	_build_categories()
	_emit_power_stability()


func _build_connections_by_government() -> void:
	connections_by_government[GovernmentType.DEMOCRACY] = [
		{"policy_id": &"consumer_goods", "holder_id": &"industrial_workers", "direction": 1, "strength": 0.9},
		{"policy_id": &"consumer_goods", "holder_id": &"merchant_class", "direction": -1, "strength": 0.3},
		{"policy_id": &"military_spending", "holder_id": &"security_bloc", "direction": 1, "strength": 0.9},
		{"policy_id": &"military_spending", "holder_id": &"scientific_community", "direction": -1, "strength": 0.4},
		{"policy_id": &"military_spending", "holder_id": &"reform_movement", "direction": -1, "strength": 0.5},
		{"policy_id": &"draft_conscription", "holder_id": &"security_bloc", "direction": 1, "strength": 0.7},
		{"policy_id": &"draft_conscription", "holder_id": &"reform_movement", "direction": -1, "strength": 0.6},
		{"policy_id": &"draft_conscription", "holder_id": &"scientific_community", "direction": -1, "strength": 0.3},
		{"policy_id": &"research_budget", "holder_id": &"scientific_community", "direction": 1, "strength": 0.9},
		{"policy_id": &"social_programs", "holder_id": &"reform_movement", "direction": 1, "strength": 0.8},
		{"policy_id": &"social_programs", "holder_id": &"merchant_class", "direction": -1, "strength": 0.4},
		{"policy_id": &"corporate_tax", "holder_id": &"merchant_class", "direction": -1, "strength": 0.8},
		{"policy_id": &"corporate_tax", "holder_id": &"reform_movement", "direction": 1, "strength": 0.5},
		{"policy_id": &"tax_rate", "holder_id": &"reform_movement", "direction": 1, "strength": 0.8},
		{"policy_id": &"tax_rate", "holder_id": &"merchant_class", "direction": -1, "strength": 0.9},
		{"policy_id": &"tax_rate", "holder_id": &"industrial_workers", "direction": -1, "strength": 0.4},
		{"policy_id": &"trade_openness", "holder_id": &"merchant_class", "direction": 1, "strength": 0.7},
		{"policy_id": &"trade_openness", "holder_id": &"industrial_workers", "direction": -1, "strength": 0.5},
		{"policy_id": &"healthcare", "holder_id": &"industrial_workers", "direction": 1, "strength": 0.5},
		{"policy_id": &"healthcare", "holder_id": &"reform_movement", "direction": 1, "strength": 0.6},
		{"policy_id": &"education", "holder_id": &"scientific_community", "direction": 1, "strength": 0.7},
		{"policy_id": &"housing", "holder_id": &"reform_movement", "direction": 1, "strength": 0.6},
		{"policy_id": &"housing", "holder_id": &"merchant_class", "direction": -1, "strength": 0.3},
	]
	connections_by_government[GovernmentType.OLIGARCHY] = [
		{"policy_id": &"resource_contracts", "holder_id": &"industrial_dynasty", "direction": 1, "strength": 0.8},
		{"policy_id": &"resource_contracts", "holder_id": &"trade_consortium", "direction": -1, "strength": 0.5},
		{"policy_id": &"noble_stipends", "holder_id": &"industrial_dynasty", "direction": 1, "strength": 0.6},
		{"policy_id": &"noble_stipends", "holder_id": &"trade_consortium", "direction": 1, "strength": 0.6},
		{"policy_id": &"noble_stipends", "holder_id": &"military_house", "direction": 1, "strength": 0.6},
		{"policy_id": &"noble_stipends", "holder_id": &"colonial_house", "direction": 1, "strength": 0.6},
		{"policy_id": &"military_spending", "holder_id": &"military_house", "direction": 1, "strength": 0.9},
		{"policy_id": &"draft_conscription", "holder_id": &"military_house", "direction": 1, "strength": 0.8},
		{"policy_id": &"colonial_autonomy", "holder_id": &"colonial_house", "direction": 1, "strength": 0.8},
		{"policy_id": &"colonial_autonomy", "holder_id": &"industrial_dynasty", "direction": -1, "strength": 0.3},
		{"policy_id": &"corporate_tax", "holder_id": &"industrial_dynasty", "direction": -1, "strength": 0.7},
		{"policy_id": &"corporate_tax", "holder_id": &"trade_consortium", "direction": -1, "strength": 0.8},
		{"policy_id": &"tax_rate", "holder_id": &"industrial_dynasty", "direction": -1, "strength": 0.8},
		{"policy_id": &"tax_rate", "holder_id": &"trade_consortium", "direction": -1, "strength": 0.9},
		{"policy_id": &"tariffs", "holder_id": &"trade_consortium", "direction": -1, "strength": 0.6},
		{"policy_id": &"tariffs", "holder_id": &"industrial_dynasty", "direction": 1, "strength": 0.4},
		{"policy_id": &"land_rights", "holder_id": &"colonial_house", "direction": 1, "strength": 0.7},
		{"policy_id": &"banking", "holder_id": &"trade_consortium", "direction": -1, "strength": 0.6},
		{"policy_id": &"labor_laws", "holder_id": &"industrial_dynasty", "direction": -1, "strength": 0.5},
	]
	connections_by_government[GovernmentType.AUTHORITARIANISM] = [
		{"policy_id": &"military_budget", "holder_id": &"high_command", "direction": 1, "strength": 0.9},
		{"policy_id": &"draft_conscription", "holder_id": &"high_command", "direction": 1, "strength": 0.8},
		{"policy_id": &"draft_conscription", "holder_id": &"regional_governor", "direction": -1, "strength": 0.4},
		{"policy_id": &"suppression_budget", "holder_id": &"security_apparatus", "direction": 1, "strength": 0.9},
		{"policy_id": &"suppression_budget", "holder_id": &"regional_governor", "direction": -1, "strength": 0.4},
		{"policy_id": &"propaganda_spending", "holder_id": &"inner_circle", "direction": 1, "strength": 0.8},
		{"policy_id": &"officer_promotions", "holder_id": &"high_command", "direction": 1, "strength": 0.7},
		{"policy_id": &"officer_promotions", "holder_id": &"inner_circle", "direction": 1, "strength": 0.4},
		{"policy_id": &"regional_autonomy", "holder_id": &"regional_governor", "direction": 1, "strength": 0.8},
		{"policy_id": &"regional_autonomy", "holder_id": &"security_apparatus", "direction": -1, "strength": 0.5},
		{"policy_id": &"surveillance", "holder_id": &"security_apparatus", "direction": 1, "strength": 0.8},
		{"policy_id": &"surveillance", "holder_id": &"regional_governor", "direction": -1, "strength": 0.5},
		{"policy_id": &"reserves", "holder_id": &"high_command", "direction": 1, "strength": 0.5},
		{"policy_id": &"reserves", "holder_id": &"inner_circle", "direction": 1, "strength": 0.4},
		{"policy_id": &"tax_rate", "holder_id": &"inner_circle", "direction": 1, "strength": 0.6},
		{"policy_id": &"tax_rate", "holder_id": &"regional_governor", "direction": -1, "strength": 0.5},
		{"policy_id": &"appointments", "holder_id": &"inner_circle", "direction": 1, "strength": 0.8},
		{"policy_id": &"appointments", "holder_id": &"high_command", "direction": 1, "strength": 0.5},
		{"policy_id": &"luxury", "holder_id": &"inner_circle", "direction": 1, "strength": 0.7},
	]
	connections_by_government[GovernmentType.THEOCRACY] = [
		{"policy_id": &"temple_budget", "holder_id": &"congregation_order", "direction": 1, "strength": 0.9},
		{"policy_id": &"heresy_suppression", "holder_id": &"inquisitorial_order", "direction": 1, "strength": 0.9},
		{"policy_id": &"heresy_suppression", "holder_id": &"scholarly_order", "direction": -1, "strength": 0.5},
		{"policy_id": &"missionary_funding", "holder_id": &"missionary_order", "direction": 1, "strength": 0.9},
		{"policy_id": &"draft_conscription", "holder_id": &"missionary_order", "direction": 1, "strength": 0.5},
		{"policy_id": &"draft_conscription", "holder_id": &"congregation_order", "direction": -1, "strength": 0.3},
		{"policy_id": &"theological_research", "holder_id": &"scholarly_order", "direction": 1, "strength": 0.8},
		{"policy_id": &"theological_research", "holder_id": &"inquisitorial_order", "direction": 1, "strength": 0.3},
		{"policy_id": &"doctrinal_strictness", "holder_id": &"inquisitorial_order", "direction": 1, "strength": 0.7},
		{"policy_id": &"doctrinal_strictness", "holder_id": &"congregation_order", "direction": -1, "strength": 0.3},
		{"policy_id": &"doctrinal_strictness", "holder_id": &"scholarly_order", "direction": -1, "strength": 0.6},
		{"policy_id": &"tithe", "holder_id": &"congregation_order", "direction": 1, "strength": 0.5},
		{"policy_id": &"tithe", "holder_id": &"missionary_order", "direction": 1, "strength": 0.4},
		{"policy_id": &"tax_rate", "holder_id": &"congregation_order", "direction": 1, "strength": 0.5},
		{"policy_id": &"tax_rate", "holder_id": &"scholarly_order", "direction": -1, "strength": 0.3},
		{"policy_id": &"sacred_sites", "holder_id": &"congregation_order", "direction": 1, "strength": 0.7},
		{"policy_id": &"sacred_sites", "holder_id": &"scholarly_order", "direction": 1, "strength": 0.5},
		{"policy_id": &"courts", "holder_id": &"inquisitorial_order", "direction": 1, "strength": 0.8},
		{"policy_id": &"courts", "holder_id": &"scholarly_order", "direction": -1, "strength": 0.4},
		{"policy_id": &"religious_education", "holder_id": &"scholarly_order", "direction": 1, "strength": 0.6},
		{"policy_id": &"religious_education", "holder_id": &"congregation_order", "direction": 1, "strength": 0.4},
	]


func _add_lever(pid: StringName, display: String, val: float, min_l: String, max_l: String, desc: String = "", dynamic_dir: bool = false) -> void:
	var p := PolicyLever.new()
	p.id = pid
	p.display_name = display
	p.value = val
	p.min_label = min_l
	p.max_label = max_l
	p.description = desc
	p.dynamic_direction = dynamic_dir
	policy_levers.append(p)


func _build_democracy_policies() -> void:
	_add_lever(&"consumer_goods", "Consumer Goods Allocation", 0.7, "Low", "High", "Controls production and distribution of consumer goods across the empire. High allocation boosts worker satisfaction but reduces industrial output for other uses.")
	_add_lever(&"military_spending", "Military Budget", 0.4, "Low", "High", "Total military expenditure as a share of imperial budget. Boosts security faction loyalty but creates tensions with scientific and reform blocs.")
	_add_lever(&"draft_conscription", "Draft / Conscription", 0.3, "Low", "High", "Conscription level. Security bloc supports it; reform and scientific blocs oppose.")
	_add_lever(&"research_budget", "Research Budget", 0.6, "Low", "High", "Direct funding to research institutions. Critical for scientific community support.")
	_add_lever(&"social_programs", "Social Programs", 0.5, "Low", "High", "Welfare programs, social safety nets, and public services. Reform bloc demands this.")
	_add_lever(&"corporate_tax", "Corporate Tax Rate", 0.25, "Low", "High", "Corporate taxation rate. High taxes fund social programs but anger the merchant class.")
	_add_lever(&"tax_rate", "Tax Rate", 0.25, "Low", "High", "Overall tax rate. 25% is neutral; higher helps reform movement, hurts merchants and workers.", true)
	_add_lever(&"trade_openness", "Trade Openness", 0.5, "Closed", "Open", "Market openness to trade. Benefits merchants but can hurt domestic industrial workers.")
	_add_lever(&"healthcare", "Healthcare", 0.45, "Low", "High", "Medical services and pharmaceutical distribution across colonies.")
	_add_lever(&"education", "Education", 0.55, "Low", "High", "Funding for schools, universities, and research training programs.")
	_add_lever(&"housing", "Housing Policy", 0.4, "Low", "High", "Policy governing habitation development priority and affordability.")


func _build_oligarchy_policies() -> void:
	_add_lever(&"resource_contracts", "Resource Contracts", 0.5, "Loose", "Tight", "Whether resource extraction rights are granted exclusively to loyal houses or open to bidding. Exclusivity rewards the Industrial Dynasty.")
	_add_lever(&"noble_stipends", "Noble Stipends", 0.3, "Low", "High", "Direct income transfers to elite houses. Expensive but broadly pleases all key holders.")
	_add_lever(&"military_spending", "Military Budget", 0.4, "Low", "High", "Fleet and army expenditure. Essential for keeping the Military House satisfied.")
	_add_lever(&"draft_conscription", "Draft / Conscription", 0.3, "Low", "High", "Conscription level. Military House supports it.")
	_add_lever(&"border_security", "Border Security", 0.5, "Low", "High", "Resources devoted to border control and customs.")
	_add_lever(&"colonial_autonomy", "Colonial Autonomy", 0.5, "Low", "High", "Degree of self-governance granted to colonial systems. Colonial Houses demand it.")
	_add_lever(&"corporate_tax", "Corporate Tax", 0.2, "Low", "High", "Taxation on corporate profits. Low rates please all economic houses.")
	_add_lever(&"tax_rate", "Tax Rate", 0.25, "Low", "High", "Overall tax rate. 25% is neutral; high tax hurts industrial and trade houses.", true)
	_add_lever(&"tariffs", "Trade Tariffs", 0.45, "Low", "High", "Import/export duties. Protects domestic industry but hurts trading houses.")
	_add_lever(&"land_rights", "Land Rights", 0.55, "Low", "High", "Policy on planetary ownership and inheritance. Colonial and industrial houses both care.")
	_add_lever(&"banking", "Banking Regulation", 0.35, "Loose", "Tight", "Financial sector regulation. Loosely regulated markets favor the Consortium.")
	_add_lever(&"labor_laws", "Labor Laws", 0.4, "Weak", "Strong", "Regulation of labor and workplace conditions. Industrial Dynasty resists strong enforcement.")


func _build_authoritarianism_policies() -> void:
	_add_lever(&"military_budget", "Military Budget", 0.6, "Low", "High", "Total military expenditure. Non-negotiable for the High Command's loyalty.")
	_add_lever(&"draft_conscription", "Draft / Conscription", 0.3, "Low", "High", "Conscription level. High Command supports; regional governors oppose.")
	_add_lever(&"suppression_budget", "Suppression Budget", 0.4, "Low", "High", "Internal security and population control budgets. Powers the Security Apparatus.")
	_add_lever(&"surveillance", "Surveillance Programs", 0.45, "Low", "High", "Intelligence network funding. The Apparatus demands full coverage.")
	_add_lever(&"border_security", "Border Security", 0.5, "Low", "High", "Resources devoted to border control and customs.")
	_add_lever(&"propaganda_spending", "Propaganda Spending", 0.3, "Low", "High", "State media and ideological messaging. Satisfies the Inner Circle's image concerns.")
	_add_lever(&"officer_promotions", "Officer Promotions", 0.5, "Low", "High", "Speed and favoritism in officer advancement. Keeps both Command and Inner Circle satisfied.")
	_add_lever(&"regional_autonomy", "Regional Autonomy", 0.3, "Low", "High", "Latitude granted to regional governors. They want it; your security apparatus hates it.")
	_add_lever(&"reserves", "Strategic Reserves", 0.5, "Low", "High", "Strategic stockpiles controlled directly by the leadership. Signals strength to all pillars.")
	_add_lever(&"tax_rate", "Tax Rate", 0.25, "Low", "High", "Overall tax rate. 25% is neutral; high tax helps inner circle, hurts regional governors.", true)
	_add_lever(&"luxury", "Luxury Goods Access", 0.35, "Restricted", "Open", "Access to luxury goods for the elite. The Inner Circle demands exclusivity.")
	_add_lever(&"consumer_goods", "Consumer Goods Allocation", 0.5, "Low", "High", "Distribution of consumer goods. Affects population satisfaction.")
	_add_lever(&"appointments", "Loyalty Appointments", 0.4, "Low", "High", "Loyalty-based rather than merit-based appointments to administrative posts.")


func _build_theocracy_policies() -> void:
	_add_lever(&"military_budget", "Military Budget", 0.4, "Low", "High", "Defense and order enforcement. Missionary and congregation orders have differing views.")
	_add_lever(&"heresy_suppression", "Heresy Suppression", 0.3, "Low", "High", "Enforcement of doctrinal purity. The Inquisitorial Order demands maximum strictness.")
	_add_lever(&"courts", "Religious Courts", 0.35, "Limited", "Full", "Parallel religious legal system. Inquisitors want full authority; scholars want limits.")
	_add_lever(&"temple_budget", "Temple Construction", 0.5, "Low", "High", "Budget for constructing temples across your worlds. Core demand of the Congregation.")
	_add_lever(&"tax_rate", "Tax Rate", 0.25, "Low", "High", "Overall tax rate. 25% is neutral; high tax funds congregation, hurts scholarly order.", true)
	_add_lever(&"tithe", "Tithe Rate", 0.45, "Low", "High", "Income extraction from believers. Funds the faith but creates pop happiness pressure.")
	_add_lever(&"consumer_goods", "Consumer Goods Allocation", 0.5, "Low", "High", "Distribution of consumer goods to the faithful.")
	_add_lever(&"sacred_sites", "Sacred Site Protection", 0.55, "Low", "High", "Protection and investment in holy locations. Widely popular across most orders.")
	_add_lever(&"missionary_funding", "Missionary Funding", 0.4, "Low", "High", "Support for expansion of the faith into new systems. The Missionary Order's purpose.")
	_add_lever(&"theological_research", "Theological Research", 0.5, "Low", "High", "Investment in scholarly theological research. Satisfies the Scholarly Order.")
	_add_lever(&"religious_education", "Religious Education", 0.5, "Low", "High", "State-funded religious schooling and doctrine training. Congregation and Scholarly orders both value it.")
	_add_lever(&"doctrinal_strictness", "Doctrinal Strictness", 0.4, "Lenient", "Strict", "How narrowly doctrine is interpreted. High strictness pleases enforcers, chafes scholars.")
	_add_lever(&"draft_conscription", "Draft / Conscription", 0.3, "Low", "High", "Conscription for missionary and defense. Missionary order supports; congregation wary.")


func _build_categories() -> void:
	# Category id -> display_name; then per-government list of policy ids for that category. Empty categories omitted.
	var cat_defs: Array[Dictionary] = [
		{"id": &"military_security", "display_name": "Military & Security", "policy_ids": _category_policy_ids_military()},
		{"id": &"economy_finance", "display_name": "Economy & Finance", "policy_ids": _category_policy_ids_economy()},
		{"id": &"social_welfare", "display_name": "Social & Welfare", "policy_ids": _category_policy_ids_social()},
		{"id": &"science_dev", "display_name": "Science & Dev", "policy_ids": _category_policy_ids_science()},
		{"id": &"governance", "display_name": "Governance", "policy_ids": _category_policy_ids_governance()},
	]
	for cat_def in cat_defs:
		var ids: Array[StringName] = cat_def.policy_ids
		if ids.is_empty():
			continue
		var levers: Array[PolicyLever] = []
		for pid in ids:
			for p in policy_levers:
				if p.id == pid:
					levers.append(p)
					break
		if levers.is_empty():
			continue
		var cat := PolicyCategory.new()
		cat.id = cat_def.id
		cat.display_name = cat_def.display_name
		cat.policies = levers
		categories.append(cat)


func _category_policy_ids_military() -> Array[StringName]:
	match current_government_type:
		GovernmentType.DEMOCRACY:
			return [&"military_spending", &"draft_conscription"]
		GovernmentType.OLIGARCHY:
			return [&"military_spending", &"draft_conscription", &"border_security"]
		GovernmentType.AUTHORITARIANISM:
			return [&"military_budget", &"draft_conscription", &"suppression_budget", &"surveillance", &"border_security"]
		GovernmentType.THEOCRACY:
			return [&"military_budget", &"heresy_suppression", &"courts"]
	return []


func _category_policy_ids_economy() -> Array[StringName]:
	match current_government_type:
		GovernmentType.DEMOCRACY:
			return [&"tax_rate", &"trade_openness", &"corporate_tax"]
		GovernmentType.OLIGARCHY:
			return [&"tax_rate", &"trade_openness", &"corporate_tax", &"tariffs", &"banking", &"noble_stipends"]
		GovernmentType.AUTHORITARIANISM:
			return [&"tax_rate", &"reserves", &"luxury"]
		GovernmentType.THEOCRACY:
			return [&"tax_rate", &"tithe"]
	return []


func _category_policy_ids_social() -> Array[StringName]:
	match current_government_type:
		GovernmentType.DEMOCRACY:
			return [&"consumer_goods", &"healthcare", &"housing"]
		GovernmentType.OLIGARCHY:
			return []
		GovernmentType.AUTHORITARIANISM:
			return [&"consumer_goods", &"propaganda_spending"]
		GovernmentType.THEOCRACY:
			return [&"consumer_goods", &"temple_budget", &"sacred_sites", &"missionary_funding"]
	return []


func _category_policy_ids_science() -> Array[StringName]:
	match current_government_type:
		GovernmentType.DEMOCRACY:
			return [&"research_budget", &"education"]
		GovernmentType.OLIGARCHY:
			return []
		GovernmentType.AUTHORITARIANISM:
			return [&"propaganda_spending"]
		GovernmentType.THEOCRACY:
			return [&"theological_research", &"religious_education"]
	return []


func _category_policy_ids_governance() -> Array[StringName]:
	match current_government_type:
		GovernmentType.DEMOCRACY:
			return [&"social_programs"]
		GovernmentType.OLIGARCHY:
			return [&"resource_contracts", &"colonial_autonomy", &"land_rights", &"labor_laws"]
		GovernmentType.AUTHORITARIANISM:
			return [&"regional_autonomy", &"officer_promotions", &"appointments", &"suppression_budget"]
		GovernmentType.THEOCRACY:
			return [&"doctrinal_strictness", &"missionary_funding", &"courts"]
	return []


func _make_holder(pid: StringName, display: String, faction: String, loyalty: float, res: String, amt: int, desc: String = "") -> KeyHolder:
	var k := KeyHolder.new()
	k.id = pid
	k.display_name = display
	k.faction_type = faction
	k.loyalty = loyalty
	k.demand_resource = res
	k.demand_amount = amt
	k.demand_fulfilled = false
	k.description = desc
	return k


func _build_democracy_key_holders() -> void:
	active_key_holders.append(_make_holder(&"industrial_workers", "Industrial Workers", "Voting Bloc", 50.0, "Consumer Goods", 50, "Represents factory workers and miners across your empire. Their support depends on material welfare and job security."))
	active_key_holders.append(_make_holder(&"scientific_community", "Scientific Community", "Voting Bloc", 50.0, "Research", 30, "Researchers, academics, and engineers. They want investment in knowledge and oppose militarism."))
	active_key_holders.append(_make_holder(&"merchant_class", "Merchant Class", "Voting Bloc", 50.0, "Energy Credits", 40, "Traders and industrialists. They want open markets and low taxation. Hurt by protectionism."))
	active_key_holders.append(_make_holder(&"security_bloc", "Security Bloc", "Voting Bloc", 50.0, "Alloys", 20, "Military veterans and law enforcement. They want a strong defense posture and feel threatened by diplomatic concessions."))
	active_key_holders.append(_make_holder(&"reform_movement", "Reform Movement", "Voting Bloc", 50.0, "Unity", 25, "Civil society activists pushing for equality and social spending. Hurt by military overextension."))


func _build_oligarchy_key_holders() -> void:
	active_key_holders.append(_make_holder(&"industrial_dynasty", "Industrial Dynasty", "Noble House", 50.0, "Minerals", 40, "Controls the empire's primary ore and alloy production. Demands exclusive contracts and resists nationalization."))
	active_key_holders.append(_make_holder(&"trade_consortium", "Trade Consortium", "Noble House", 50.0, "Energy Credits", 35, "Major interstellar trading houses. Requires favorable tariffs and market access guarantees."))
	active_key_holders.append(_make_holder(&"military_house", "Military House", "Noble House", 50.0, "Alloys", 30, "Old noble families who control significant fleet tonnage. Want war, spoils, and command appointments."))
	active_key_holders.append(_make_holder(&"colonial_house", "Colonial House", "Noble House", 50.0, "Food", 25, "Established colonial governors. Demand autonomy over their systems and resist central taxation."))


func _build_authoritarianism_key_holders() -> void:
	active_key_holders.append(_make_holder(&"high_command", "High Command", "Faction", 50.0, "Alloys", 40, "The senior officer corps controlling fleet and ground forces. They want military budget, promotions, and war opportunities."))
	active_key_holders.append(_make_holder(&"security_apparatus", "Security Apparatus", "Faction", 50.0, "Influence", 20, "Secret police and internal surveillance. Demands autonomy, suppression funding, and no civilian oversight."))
	active_key_holders.append(_make_holder(&"inner_circle", "Inner Circle", "Faction", 50.0, "Consumer Goods", 30, "Your closest advisors and political allies. Demand exclusive access, luxury goods, and loyalty appointments."))
	active_key_holders.append(_make_holder(&"regional_governor", "Regional Governor", "Faction", 50.0, "Autonomy", 1, "Appointed administrators across your empire's regions. Demand local control and resent central directives."))


func _build_theocracy_key_holders() -> void:
	active_key_holders.append(_make_holder(&"congregation_order", "Congregation Order", "Order", 50.0, "Consumer Goods", 25, "The mass-observance arm. Demands temples, pop conversion programs, and zero tolerance for alien faiths."))
	active_key_holders.append(_make_holder(&"inquisitorial_order", "Inquisitorial Order", "Order", 50.0, "Influence", 30, "Doctrinal enforcers. Non-negotiable demands — any tolerance of heresy collapses their loyalty instantly."))
	active_key_holders.append(_make_holder(&"missionary_order", "Missionary Order", "Order", 50.0, "Unity", 20, "The expansion arm. Treats colonization as sacred duty and wants missionary funding above all else."))
	active_key_holders.append(_make_holder(&"scholarly_order", "Scholarly Order", "Order", 50.0, "Research", 35, "Theological scholars. Want research investment and clash with the Inquisitorial Order over interpretation."))


func get_power_stability() -> float:
	if active_key_holders.is_empty():
		return 0.0
	var sum: float = 0.0
	for kh in active_key_holders:
		sum += kh.loyalty
	return sum / float(active_key_holders.size())


func process_monthly_tick(_empire: Variant) -> void:
	if _empire == null:
		return
	for kh in active_key_holders:
		if not kh.demand_fulfilled:
			kh.loyalty = clampf(kh.loyalty - loyalty_decay_per_unfulfilled, 0.0, 100.0)
			if EventBus != null:
				EventBus.key_holder_loyalty_changed.emit(kh.id, kh.loyalty)
	if EventBus != null:
		EventBus.power_stability_changed.emit(get_power_stability())


func fulfill_demand(key_holder_id: StringName) -> void:
	for kh in active_key_holders:
		if kh.id != key_holder_id:
			continue
		kh.demand_fulfilled = true
		kh.loyalty = clampf(kh.loyalty + loyalty_fulfill_bonus, 0.0, 100.0)
		if EventBus != null:
			EventBus.demand_fulfilled.emit(key_holder_id)
			EventBus.key_holder_loyalty_changed.emit(kh.id, kh.loyalty)
			EventBus.power_stability_changed.emit(get_power_stability())
		var timer: SceneTreeTimer = get_tree().create_timer(new_demand_delay_seconds)
		timer.timeout.connect(_on_new_demand_timeout.bind(key_holder_id))
		return


func _on_new_demand_timeout(key_holder_id: StringName) -> void:
	for kh in active_key_holders:
		if kh.id != key_holder_id:
			continue
		kh.demand_fulfilled = false
		var idx: int = randi() % _new_demand_resources.size()
		kh.demand_resource = _new_demand_resources[idx]
		kh.demand_amount = _new_demand_amounts[idx]
		if EventBus != null:
			EventBus.key_holder_loyalty_changed.emit(kh.id, kh.loyalty)
			EventBus.power_stability_changed.emit(get_power_stability())
		return


func _emit_power_stability() -> void:
	if EventBus != null:
		EventBus.power_stability_changed.emit(get_power_stability())
