"""Generate tech_tree.tscn from techs.json. Run: python scripts/editor/gen_tech_tree_json.py"""
import json
import os

BRANCH_ORDER = ["physical", "social", "xenological"]
CARD_W, CARD_H = 260, 140
PAD_X, PAD_Y = 32, 28
BRANCH_GAP = 460
LABEL_ROW_H = 28

def main():
    base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    techs_path = os.path.join(base, "data", "techs.json")
    out_path = os.path.join(base, "scenes", "ui", "technology_cards", "tech_tree.tscn")
    with open(techs_path, "r", encoding="utf-8") as f:
        techs = json.load(f)
    grouped = {b: {} for b in BRANCH_ORDER}
    for t in techs:
        cat = int(t.get("category", 0))
        branch = BRANCH_ORDER[cat]
        tier = int(t.get("tier", 1))
        if tier not in grouped[branch]:
            grouped[branch][tier] = []
        grouped[branch][tier].append(t)
    list_ = []
    res_id = 0
    ext_resources = ['[ext_resource type="Script" uid="uid://dkarn0eovpe7d" path="res://scenes/ui/tech_tree_lines.gd" id="1_lines"]']
    branch_idx = 0
    for branch_key in BRANCH_ORDER:
        if branch_key not in grouped:
            branch_idx += 1
            continue
        tiers = grouped[branch_key]
        for tier_num in sorted(tiers.keys()):
            techs_in_tier = tiers[tier_num]
            for t_idx, tech_def in enumerate(techs_in_tier):
                tid = tech_def.get("id", "")
                card_path = tech_def.get("card_scene", "res://scenes/ui/tech_card.tscn")
                x = (int(tier_num) - 1) * (CARD_W + PAD_X) + 32
                y = branch_idx * BRANCH_GAP + LABEL_ROW_H + t_idx * (CARD_H + PAD_Y)
                ext_resources.append('[ext_resource type="PackedScene" path="%s" id="2_%d"]' % (card_path, res_id))
                list_.append({"id": tid, "res_id": res_id, "x": x, "y": y})
                res_id += 1
        branch_idx += 1
    lines = [
        '[gd_scene load_steps=%d format=3 uid="uid://bv743jqoto8l3"]' % len(ext_resources),
        "",
    ] + ext_resources + [
        "",
        '[node name="TechTree" type="Control"]',
        "custom_minimum_size = Vector2(1580, 1480)",
        "layout_mode = 3",
        "anchors_preset = 15",
        "anchor_right = 1.0",
        "anchor_bottom = 1.0",
        "offset_left = 16.0",
        "offset_top = 32.0",
        "offset_right = 16.0",
        "offset_bottom = 72.0",
        "grow_horizontal = 2",
        "grow_vertical = 2",
        "",
        '[node name="TreeCanvas" type="Control" parent="."]',
        "custom_minimum_size = Vector2(1580, 1480)",
        "layout_mode = 1",
        "anchors_preset = 15",
        "anchor_right = 1.0",
        "anchor_bottom = 1.0",
        "grow_horizontal = 2",
        "grow_vertical = 2",
        "",
        '[node name="Background" type="ColorRect" parent="TreeCanvas"]',
        "z_index = -2",
        "layout_mode = 1",
        "anchors_preset = 15",
        "anchor_right = 1.0",
        "anchor_bottom = 1.0",
        "offset_left = -840.0",
        "offset_top = -440.0",
        "offset_right = 4096.0",
        "offset_bottom = 2936.0",
        "grow_horizontal = 2",
        "grow_vertical = 2",
        "mouse_filter = 2",
        "color = Color(0.055, 0.065, 0.1, 0.97)",
        "",
        '[node name="LinesLayer" type="Control" parent="TreeCanvas"]',
        "z_index = -1",
        "layout_mode = 1",
        "anchors_preset = 15",
        "anchor_right = 1.0",
        "anchor_bottom = 1.0",
        "grow_horizontal = 2",
        "grow_vertical = 2",
        "mouse_filter = 2",
        'script = ExtResource("1_lines")',
        "",
    ]
    names = ["Physical Sciences", "Social Sciences", "Xenological Sciences"]
    for i in range(3):
        lines.extend([
            '[node name="BranchLabel%d" type="Label" parent="TreeCanvas"]' % i,
            "layout_mode = 3",
            "position = Vector2(32, %d)" % (6 + i * BRANCH_GAP),
            "theme_override_font_sizes/font_size = 14",
            'text = "%s"' % names[i],
            "",
        ])
    for item in list_:
        lines.extend([
            '[node name="%s" parent="TreeCanvas" instance=ExtResource("2_%d")]' % (item["id"], item["res_id"]),
            "layout_mode = 3",
            "position = Vector2(%d, %d)" % (item["x"], item["y"]),
            "",
        ])
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("Wrote", out_path, "with", len(list_), "tech cards.")

if __name__ == "__main__":
    main()
