extends Node
## Central event bus for game signals. Autoload: EventBus

# Pause / time
signal pause_state_changed(is_paused: bool)

# Building / job assignment
signal job_assignment_updated(planet: Variant)
signal job_slot_filled(planet: Variant, building: Variant, assignment: Variant)
signal job_slot_emptied(planet: Variant, building: Variant, assignment: Variant)
signal pop_became_idle(planet: Variant, pop_id: int)

# Building cascade (from building prompt)
signal building_went_offline(planet: Variant, building: Variant, reason: String)
signal building_cascade_warning(planet: Variant, building: Variant, cascade_desc: String)
signal building_came_online(planet: Variant, building: Variant)
signal matrioshka_destroyed()

# Leaders
signal leader_levelled_up(leader: Variant, new_level: int)
signal leader_trait_choice_ready(leader: Variant, options: Array)
signal leader_died(leader: Variant)
signal leader_recruited(leader: Variant)
signal leader_dismissed(leader: Variant)
signal paragon_available(paragon_trait_id: String, source_event: String)

# Tech / research
signal tech_research_confirmed(tech_id: String)

# Council
signal council_agenda_launched(agenda: Variant)
signal council_agenda_completed(agenda: Variant)
signal council_position_unfilled(position_id: String)
signal council_position_filled(position_id: String, leader: Variant)
