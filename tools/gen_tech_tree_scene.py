#!/usr/bin/env python3
"""
Update ui/tech_tree/technology_cards/tech_tree.tscn with all techs from data/techs.json.
Replaces card ext_resources and tech_* nodes; updates canvas size. Run from project root.
"""
import json
import re
from pathlib import Path

CARD_W = 260
CARD_H = 140
PAD_X = 32
PAD_Y = 28
BRANCH_GAP = 460
LABEL_ROW_H = 28
DEFAULT_CARD = "res://ui/components/tech_card.tscn"


def main():
    root = Path(__file__).resolve().parent.parent
    techs_path = root / "data" / "techs.json"
    tscn_path = root / "ui" / "tech_tree" / "technology_cards" / "tech_tree.tscn"

    with open(techs_path, encoding="utf-8") as f:
        techs = json.load(f)

    branch_order = ["physical", "social", "xenological"]
    grouped = {b: {} for b in branch_order}
    for t in techs:
        cat = int(t.get("category", 0))
        branch = branch_order[cat]
        tier = int(t.get("tier", 1))
        if tier not in grouped[branch]:
            grouped[branch][tier] = []
        grouped[branch][tier].append(t)

    list_items = []
    res_id = 0
    for branch_idx, branch_key in enumerate(branch_order):
        if branch_key not in grouped:
            continue
        tiers = grouped[branch_key]
        for tier_num in sorted(tiers.keys()):
            techs_in_tier = tiers[tier_num]
            for t_idx, tech_def in enumerate(techs_in_tier):
                tid = tech_def.get("id", "")
                if not tid:
                    continue
                x = (tier_num - 1) * (CARD_W + PAD_X) + 32
                y = branch_idx * BRANCH_GAP + LABEL_ROW_H + t_idx * (CARD_H + PAD_Y)
                list_items.append({"id": tid, "x": x, "y": y, "res_id": res_id})
                res_id += 1

    num_cards = len(list_items)
    canvas_w = 15 * (CARD_W + PAD_X) + 32 + CARD_W
    canvas_h = 3 * BRANCH_GAP + 2000

    lines = tscn_path.read_text(encoding="utf-8").splitlines(keepends=True)

    # 1) Update load_steps on first line
    n_ext = 2 + num_cards
    n_sub = sum(1 for L in lines if L.strip().startswith("[sub_resource "))
    for i, L in enumerate(lines):
        if L.strip().startswith("[gd_scene"):
            lines[i] = re.sub(r"load_steps=\d+", f"load_steps={n_ext + n_sub}", L, count=1)
            break

    # 2) Replace ext_resources: keep line 0 (gd_scene), replace lines starting at first ext_resource until we hit sub_resource
    new_ext = [
        '[ext_resource type="Script" uid="uid://dkarn0eovpe7d" path="res://ui/tech_tree/tech_tree_lines.gd" id="1_lines"]\n',
    ]
    for i in range(num_cards):
        new_ext.append(f'[ext_resource type="PackedScene" path="{DEFAULT_CARD}" id="2_{i}"]\n')
    new_ext.append('[ext_resource type="Script" uid="uid://dcjbijd8p8fmy" path="res://ui/tech_tree/technology_cards/tech_tree.gd" id="4_root"]\n')

    start_ext = None
    end_ext = None
    for i, L in enumerate(lines):
        if '[ext_resource type="Script" uid="uid://dkarn0eovpe7d"' in L and "1_lines" in L:
            start_ext = i
        if start_ext is not None and L.strip().startswith("[sub_resource "):
            end_ext = i
            break
    if start_ext is not None and end_ext is not None:
        lines = lines[:start_ext] + new_ext + ["\n"] + lines[end_ext:]

    # 3) Replace tech_* nodes: find the block after LinesLayer metadata and BranchLabel0/1/2, before DetailPanel
    text = "".join(lines)
    # Pattern: after "metadata/card_half_size" and "BranchLabel2" block, we have tech_ nodes until DetailPanel
    marker_after_br2 = 'text = "Xenological Sciences"'
    marker_detail = '[node name="DetailPanel"'
    idx_br2_end = text.find(marker_after_br2)
    if idx_br2_end == -1:
        print("Warning: could not find BranchLabel2 end")
    else:
        idx_br2_end = text.find("\n\n", idx_br2_end) + 2
    idx_detail = text.find(marker_detail)
    if idx_br2_end != -1 and idx_detail != -1:
        tech_nodes_str = "".join(
            f'[node name="{item["id"]}" parent="ContentHBox/TreeCanvas" instance=ExtResource("2_{item["res_id"]}")]\n'
            f"layout_mode = 3\n"
            f'position = Vector2({item["x"]}, {item["y"]})\n\n'
            for item in list_items
        )
        text = text[:idx_br2_end] + tech_nodes_str + text[idx_detail - 1 :]

    # 4) Update canvas sizes
    text = re.sub(
        r'(\[node name="TreeCanvas" type="Control" parent="ContentHBox"\][^\n]*\n[^\n]*\n)custom_minimum_size = Vector2\(\d+, \d+\)',
        f"\\1custom_minimum_size = Vector2({int(canvas_w)}, {int(canvas_h)})",
        text,
        count=1,
    )
    # Background (ColorRect under TreeCanvas) - update offset_right and offset_bottom
    text = re.sub(
        r'(parent="ContentHBox/TreeCanvas"\][^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n[^\n]*\n)offset_left = -?\d+[.\d]*\noffset_top = -?\d+[.\d]*\noffset_right = [\d.]+\noffset_bottom = [\d.]+',
        f'\\1offset_left = -540.0\noffset_top = -348.0\noffset_right = {int(canvas_w + 200)}\noffset_bottom = {int(canvas_h + 200)}',
        text,
        count=1,
    )
    # ContentBoundary
    text = re.sub(
        r'(\[node name="ContentBoundary"[^\]]*\]\n[^\n]*\n[^\n]*\n)offset_left = [-\d.]+\noffset_top = [-\d.]+\noffset_right = [\d.]+\noffset_bottom = [\d.]+',
        f"\\1offset_left = -368.0\noffset_top = -336.0\noffset_right = {int(canvas_w + 200)}\noffset_bottom = {int(canvas_h + 200)}",
        text,
        count=1,
    )

    tscn_path.write_text(text, encoding="utf-8")
    print(f"Updated {tscn_path} with {num_cards} tech cards, canvas {int(canvas_w)}x{int(canvas_h)}")


if __name__ == "__main__":
    main()
