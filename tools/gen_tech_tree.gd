extends SceneTree
## Run: godot -s scripts/editor/gen_tech_tree.gd
func _init() -> void:
	var path := "res://data/techs.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("Missing ", path)
		quit(1)
		return
	var json := JSON.new()
	json.parse(f.get_as_text())
	f.close()
	var techs: Array = json.data if json.data is Array else []
	var branch_order: Array = ["physical", "social", "xenological"]
	var grouped: Dictionary = {}
	for b in branch_order:
		grouped[b] = {}
	for t in techs:
		var cat: int = int(t.get("category", 0))
		var branch: String = branch_order[cat]
		var tier: int = int(t.get("tier", 1))
		if not grouped[branch].has(tier):
			grouped[branch][tier] = []
		grouped[branch][tier].append(t)
	const CARD_W := 260
	const PAD_X := 32
	const BRANCH_GAP := 460
	const LABEL_ROW_H := 28
	const CARD_H := 140
	const PAD_Y := 28
	var list: Array = []
	var res_id := 0
	var ext_resources: Array = ['[ext_resource type="Script" path="res://ui/tech_tree/tech_tree_lines.gd" id="1_lines"]']
	var branch_idx := 0
	for branch_key in branch_order:
		if not grouped.has(branch_key):
			branch_idx += 1
			continue
		var tiers: Dictionary = grouped[branch_key]
		var tier_nums: Array = tiers.keys()
		tier_nums.sort()
		for tier_num in tier_nums:
			var techs_in_tier: Array = tiers[tier_num]
			for t in range(techs_in_tier.size()):
				var tech_def: Dictionary = techs_in_tier[t]
				var tid: String = tech_def.get("id", "")
				var card_path: String = tech_def.get("card_scene", "res://ui/components/tech_card.tscn")
				var x: int = (tier_num - 1) * (CARD_W + PAD_X) + 32
				var y: int = branch_idx * BRANCH_GAP + LABEL_ROW_H + t * (CARD_H + PAD_Y)
				ext_resources.append('[ext_resource type="PackedScene" path="%s" id="2_%d"]' % [card_path, res_id])
				list.append({ id = tid, x = x, y = y, res_id = res_id })
				res_id += 1
		branch_idx += 1
	var out_path := "res://ui/tech_tree/technology_cards/tech_tree.tscn"
	var lines: PackedStringArray = []
	lines.append('[gd_scene load_steps=%d format=3 uid="uid://tech_tree_full_001"]' % (1 + ext_resources.size()))
	lines.append("")
	for s in ext_resources:
		lines.append(s)
	lines.append("")
	lines.append('[node name="TechTree" type="Control"]')
	lines.append("layout_mode = 3")
	lines.append("anchors_preset = 15")
	lines.append("anchor_right = 1.0")
	lines.append("anchor_bottom = 1.0")
	lines.append("grow_horizontal = 2")
	lines.append("grow_vertical = 2")
	lines.append("custom_minimum_size = Vector2(1580, 1480)")
	lines.append("")
	lines.append('[node name="TreeCanvas" type="Control" parent="."]')
	lines.append("layout_mode = 1")
	lines.append("anchors_preset = 15")
	lines.append("anchor_right = 1.0")
	lines.append("anchor_bottom = 1.0")
	lines.append("grow_horizontal = 2")
	lines.append("grow_vertical = 2")
	lines.append("custom_minimum_size = Vector2(1580, 1480)")
	lines.append("")
	lines.append('[node name="Background" type="ColorRect" parent="TreeCanvas"]')
	lines.append("layout_mode = 1")
	lines.append("anchors_preset = 15")
	lines.append("anchor_right = 1.0")
	lines.append("anchor_bottom = 1.0")
	lines.append("color = Color(0.055, 0.065, 0.1, 0.97)")
	lines.append("mouse_filter = 2")
	lines.append("z_index = -2")
	lines.append("")
	lines.append('[node name="LinesLayer" type="Control" parent="TreeCanvas"]')
	lines.append("layout_mode = 1")
	lines.append("anchors_preset = 15")
	lines.append("anchor_right = 1.0")
	lines.append("anchor_bottom = 1.0")
	lines.append("mouse_filter = 2")
	lines.append("script = ExtResource(\"1_lines\")")
	lines.append("z_index = -1")
	lines.append("")
	var names := ["Physical Sciences", "Social Sciences", "Xenological Sciences"]
	for i in range(3):
		lines.append('[node name="BranchLabel%d" type="Label" parent="TreeCanvas"]' % i)
		lines.append("layout_mode = 3")
		lines.append("position = Vector2(32, %d)" % (6 + i * BRANCH_GAP))
		lines.append("theme_override_font_sizes/font_size = 14")
		lines.append("text = \"%s\"" % names[i])
		lines.append("z_index = 0")
		lines.append("")
	for item in list:
		lines.append('[node name="%s" parent="TreeCanvas" instance=ExtResource("2_%d")]' % [item.id, item.res_id])
		lines.append("layout_mode = 3")
		lines.append("position = Vector2(%d, %d)" % [item.x, item.y])
		lines.append("")
	var fout := FileAccess.open(out_path, FileAccess.WRITE)
	fout.store_string("\n".join(lines))
	fout.close()
	print("Wrote ", out_path, " with ", list.size(), " tech cards.")
	quit(0)