#!/usr/bin/env python3
"""
Generate data/TECHNOLOGIES.md from data/techs.json.
Technologies are grouped by tree (Physical, Social, Xenological) and tier,
with name and description for each. Run from project root.
"""
import json
from pathlib import Path

TREE_NAMES = {
    0: "Physical Sciences",
    1: "Social Sciences",
    2: "Xenological Sciences",
}


def main():
    root = Path(__file__).resolve().parent.parent
    techs_path = root / "data" / "techs.json"
    out_path = root / "data" / "TECHNOLOGIES.md"

    with open(techs_path, encoding="utf-8") as f:
        techs = json.load(f)

    # Group by category then tier; sort techs within tier by name_key
    grouped = {}
    for t in techs:
        cat = int(t.get("category", 0))
        tier = int(t.get("tier", 1))
        if cat not in grouped:
            grouped[cat] = {}
        if tier not in grouped[cat]:
            grouped[cat][tier] = []
        grouped[cat][tier].append(t)

    for cat in grouped:
        for tier in grouped[cat]:
            grouped[cat][tier].sort(key=lambda x: (x.get("name_key") or x.get("id", "")))

    lines = [
        "# Stellar Dominion — Technology List",
        "",
        "Technologies are defined in `techs.json`. Trees: **Physical** (0), **Social** (1), **Xenological** (2).",
        "",
        "---",
        "",
    ]

    for cat in sorted(grouped.keys()):
        tree_name = TREE_NAMES.get(cat, f"Category {cat}")
        lines.append(f"## {tree_name}")
        lines.append("")

        for tier in sorted(grouped[cat].keys()):
            lines.append(f"### Tier {tier}")
            lines.append("")

            for t in grouped[cat][tier]:
                name = t.get("name_key") or t.get("id", "Unknown")
                desc = t.get("description") or "No description."
                # Use #### for tech name so description is plain paragraph (no accidental heading)
                lines.append(f"#### {name}")
                lines.append("")
                lines.append(desc)
                lines.append("")
                lines.append("")

        lines.append("")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
