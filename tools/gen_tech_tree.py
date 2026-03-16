import json
import os

os.chdir(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
with open("data/techs.json") as f:
    techs = json.load(f)
branch_order = ["physical", "social", "xenological"]
grouped = {b: {} for b in branch_order}
for t in techs:
    cat = int(t.get("category", 0))
    branch = branch_order[cat]
    tier = int(t.get("tier", 1))
    grouped[branch].setdefault(tier, []).append(t)
CARD_W, CARD_H = 260, 140
PAD_X, PAD_Y = 32, 28
BRANCH_GAP, LABEL_ROW_H = 460, 28
ext = ['[ext_resource type="Script" path="res://scenes/ui/tech_tree_lines.gd" id="1_lines"]']
list_ = []
res_id = 0
for bi, branch_key in enumerate(branch_order):
    tiers = grouped.get(branch_key, {})
    for tier_num in sorted(tiers.keys()):
        for t_idx, tech in enumerate(tiers[tier_num]):
            tid = tech.get("id", "")
            path = tech.get("card_scene", "res://scenes/ui/tech_card.tscn")
            x = (tier_num - 1) * (CARD_W + PAD_X) + 32
            y = bi * BRANCH_GAP + LABEL_ROW_H + t_idx * (CARD_H + PAD_Y)
            ext.append('[ext_resource type="PackedScene" path="%s" id="2_%d"]' % (path, res_id))
            list_.append((tid, x, y, res_id))
            res_id += 1
lines = [
    "[gd_scene load_steps=%d format=3 uid=\"uid://tech_tree_full_001\"]" % (1 + len(ext)),
    "",
] + ext + [
    "",
    '[node name="TechTree" type="Control"]',
    "layout_mode = 3",
    "anchors_preset = 15",
    "anchor_right = 1.0",
    "anchor_bottom = 1.0",
    "grow_horizontal = 2",
    "grow_vertical = 2",
    "custom_minimum_size = Vector2(1580, 1480)",
    "",
    '[node name="TreeCanvas" type="Control" parent="."]',
    "layout_mode = 1",
    "anchors_preset = 15",
    "anchor_right = 1.0",
    "anchor_bottom = 1.0",
    "grow_horizontal = 2",
    "grow_vertical = 2",
    "custom_minimum_size = Vector2(1580, 1480)",
    "",
    '[node name="Background" type="ColorRect" parent="TreeCanvas"]',
    "layout_mode = 1",
    "anchors_preset = 15",
    "anchor_right = 1.0",
    "anchor_bottom = 1.0",
    "color = Color(0.055, 0.065, 0.1, 0.97)",
    "mouse_filter = 2",
    "z_index = -2",
    "",
    '[node name="LinesLayer" type="Control" parent="TreeCanvas"]',
    "layout_mode = 1",
    "anchors_preset = 15",
    "anchor_right = 1.0",
    "anchor_bottom = 1.0",
    "mouse_filter = 2",
    'script = ExtResource("1_lines")',
    "z_index = -1",
    "",
]
for i, name in enumerate(["Physical Sciences", "Social Sciences", "Xenological Sciences"]):
    lines += [
        '[node name="BranchLabel%d" type="Label" parent="TreeCanvas"]' % i,
        "layout_mode = 3",
        "position = Vector2(32, %d)" % (6 + i * BRANCH_GAP),
        "theme_override_font_sizes/font_size = 14",
        'text = "%s"' % name,
        "z_index = 0",
        "",
    ]
for tid, x, y, rid in list_:
    lines += [
        '[node name="%s" parent="TreeCanvas" instance=ExtResource("2_%d")]' % (tid, rid),
        "layout_mode = 3",
        "position = Vector2(%d, %d)" % (x, y),
        "",
    ]
out_path = "scenes/ui/technology_cards/tech_tree.tscn"
with open(out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("Wrote", out_path, "with", len(list_), "tech cards")
