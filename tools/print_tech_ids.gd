extends SceneTree
## Prints all tech ids from data/techs.json grouped by branch and tier for copy-paste into prerequisites.
## Run: godot -s tools/print_tech_ids.gd

func _init() -> void:
	var path := "res://data/techs.json"
	if not FileAccess.file_exists(path):
		print("Missing ", path)
		quit(1)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("Could not open ", path)
		quit(1)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		f.close()
		print("Invalid JSON in ", path)
		quit(1)
		return
	f.close()
	var techs: Array = json.data if json.data is Array else []
	var branch_order: Array = ["physical", "social", "xenological"]
	var grouped: Dictionary = {}
	for b in branch_order:
		grouped[b] = {}
	for t in techs:
		var cat: int = int(t.get("category", 0))
		var branch: String = branch_order[clampi(cat, 0, 2)]
		var tier: int = int(t.get("tier", 1))
		if not grouped[branch].has(tier):
			grouped[branch][tier] = []
		grouped[branch][tier].append(t.get("id", ""))
	print("--- Tech IDs by branch and tier (use in prerequisites array) ---")
	for branch in branch_order:
		var tiers: Dictionary = grouped[branch]
		if tiers.is_empty():
			continue
		print("\n%s:" % branch.capitalize())
		var tier_nums: Array = tiers.keys()
		tier_nums.sort()
		for tier_num in tier_nums:
			var ids: Array = tiers[tier_num]
			print("  Tier %d: %s" % [tier_num, ", ".join(ids)])
	print("\n--- Flat list by branch (for copy-paste) ---")
	for branch in branch_order:
		var all_ids: Array = []
		var tiers: Dictionary = grouped[branch]
		var tier_nums: Array = tiers.keys()
		tier_nums.sort()
		for tier_num in tier_nums:
			for tid in tiers[tier_num]:
				all_ids.append(tid)
		if all_ids.size() > 0:
			print("%s: %s" % [branch.capitalize(), ", ".join(all_ids)])
	quit(0)
