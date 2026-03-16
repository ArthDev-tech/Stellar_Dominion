@tool
extends Node
## Holds an editable reference to the job balance config so all job definitions (output and upkeep)
## can be edited in one place. Assign res://data/job_balance.tres if empty.

@export_group("Job balance")
@export var job_balance_config: JobBalanceConfig = null
