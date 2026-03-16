class_name JobDefinitionResource
extends Resource
## One job type's balance: output resource/amount and upkeep. Inspector-editable for tuning.

@export_group("Identity")
@export var job_id: String = ""
@export var name_key: String = ""

@export_group("Output")
## GameResources.ResourceType (int): 0=Energy, 1=Minerals, 2=Food, 3=Alloys, 4=Research, 7=Unity, etc. Use -1 for no output.
@export var output_resource_type: int = 0
@export var output_amount: float = 0.0

@export_group("Upkeep")
## Resource type (int) -> amount per pop per month. E.g. metallurgist: { 1: 1.0 } = 1 Minerals per pop.
@export var upkeep: Dictionary = {}
