@tool
class_name JobSlotsController
extends Node
## Single source of job slots for this building or district scene.
## When present and non-empty, Colony and def loaders use this instead of definition.jobs.
## Format: job_id (String) -> count (int), e.g. { "technician": 2, "miner": 1 }.

@export_group("Jobs")
@export var jobs: Dictionary = {}
