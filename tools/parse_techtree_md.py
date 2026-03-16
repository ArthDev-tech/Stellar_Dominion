#!/usr/bin/env python3
"""
Parse stellar_dominion_techtree_v2.md and emit data/techs.json.
Run from project root: python tools/parse_techtree_md.py [path_to.md]
Default input: downloads/stellar_dominion_techtree_v2.md or same-name in cwd.
Output: data/techs.json
"""
import re
import json
import sys
from pathlib import Path


def slug(name: str) -> str:
    """Tech name -> id suffix (snake_case). Strip path labels and cross-branch notes."""
    s = name.strip()
    # Remove [Path A], [Path B], [Shared] and *(Cross-Branch Gate)* etc.
    s = re.sub(r'^\[Path [AB]\]\s*', '', s)
    s = re.sub(r'^\[Shared\]\s*', '', s)
    s = re.sub(r'\s*\*\(Cross-Branch Gate[^)]*\)\*', '', s)
    s = re.sub(r'\s*\(Cross-Branch Gate prerequisite\)', '', s)
    s = s.strip()
    # Snake case: replace spaces/special with underscore, lowercase
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s-]+', '_', s).lower()
    return s


def tech_id(name: str) -> str:
    return 'tech_' + slug(name)


def parse_prereq_line(line: str) -> list[str]:
    """Parse **Prerequisites:** line into list of tech names (for later id resolution)."""
    line = line.strip()
    if not line or line.lower() == 'none':
        return []
    # Normalize: split by + or , and " OR " (treat OR as separate prereqs; game uses AND, so we add both)
    parts = re.split(r'\s*\+\s*|\s+OR\s+|,(?![^(]*\))', line)
    out = []
    for p in parts:
        # Strip parentheticals like (Phys T3), (Xeno T4), (Soc T8 Shared), (Phys T8A), (Phys T9B)
        name = re.sub(r'\s*\([^)]+\)\s*', ' ', p).strip()
        # Strip leading [Path A] etc.
        name = re.sub(r'^\[Path [AB]\]\s*', '', name)
        name = re.sub(r'^\[Shared\]\s*', '', name)
        name = name.strip()
        if name and name.lower() != 'none':
            out.append(name)
    return out


def resolve_prereqs(prereq_names: list[str], name_to_id: dict[str, str]) -> list[str]:
    """Resolve tech names to ids. Prefer exact match then match ignoring path/prefix."""
    ids = []
    for name in prereq_names:
        n = name.strip()
        if n in name_to_id:
            ids.append(name_to_id[n])
            continue
        # Try normalized: strip any remaining (Branch T N) and trim
        nnorm = re.sub(r'\s*\([^)]*\)\s*', ' ', n).strip()
        if nnorm in name_to_id:
            ids.append(name_to_id[nnorm])
            continue
        # Try by slug match
        target_slug = slug(n)
        for k, tid in name_to_id.items():
            if slug(k) == target_slug:
                ids.append(tid)
                break
        else:
            # Keep as missing for debugging
            pass
    return list(dict.fromkeys(ids))  # dedupe order-preserving


def cost_for_tier(tier: int, base: int = 50) -> int:
    """RP cost: base * 2^(tier-1). Cap at 99999 for sanity."""
    c = base * (2 ** (tier - 1))
    return min(c, 99999)


def main():
    root = Path(__file__).resolve().parent.parent
    if len(sys.argv) > 1:
        md_path = Path(sys.argv[1])
    else:
        # Prefer project data copy, then Downloads
        md_path = root / "data" / "stellar_dominion_techtree_v2.md"
        if not md_path.exists():
            md_path = Path.home() / "Downloads" / "stellar_dominion_techtree_v2.md"
    if not md_path.exists():
        print(f"Not found: {md_path}", file=sys.stderr)
        sys.exit(1)

    text = md_path.read_text(encoding="utf-8")
    out_path = root / "data" / "techs.json"

    # Branch section headers
    PHYSICAL = "# PHYSICAL SCIENCES"
    SOCIAL = "# SOCIAL SCIENCES"
    XENOLOGICAL = "# XENOLOGICAL SCIENCES"

    # Split into three big sections
    def find_section(title: str) -> tuple[int, int]:
        start = text.find(title)
        if start == -1:
            return -1, -1
        end = len(text)
        for other in [PHYSICAL, SOCIAL, XENOLOGICAL]:
            if other == title:
                continue
            i = text.find(other, start + 1)
            if i != -1:
                end = min(end, i)
        return start, end

    raw_techs: list[dict] = []  # { branch, tier, name, prereq_line, description, unlocks }

    for branch_title, category in [
        (PHYSICAL, 0),
        (SOCIAL, 1),
        (XENOLOGICAL, 2),
    ]:
        start, end = find_section(branch_title)
        if start == -1:
            continue
        section = text[start:end]

        # Find all ## Tier N
        tier_blocks = list(re.finditer(r'^## Tier (\d+)\s*[—\-].*?(?=^## |\Z)', section, re.MULTILINE | re.DOTALL))
        for m in tier_blocks:
            tier_num = int(m.group(1))
            block = m.group(0)
            # Each tech: ### Name then **Prerequisites:** then paragraph then **Unlocks:**
            tech_pattern = re.compile(
                r'^### (.+?) \n'
                r'\*\*Prerequisites:\*\*\s*(.*?)(?=\n\n|\n\*\*Unlocks)'
                r'(?:\n\*\*Unlocks:\*\*\s*(.*?))?(?=\n\n|> |\n### |\n## |\Z)',
                re.MULTILINE | re.DOTALL
            )
            # Simpler: find ### lines, then scan forward for Prerequisites and description
            for h3 in re.finditer(r'^### (.+)$', block, re.MULTILINE):
                name_line = h3.group(1).strip()
                start_off = h3.end()
                rest = block[start_off:]
                prereq_line = ""
                desc = ""
                unlocks_line = ""

                prereq_m = re.search(r'^\*\*Prerequisites:\*\*\s*(.*?)(?=\n\n|\n\*\*Unlocks|\n[A-Z]|\Z)', rest, re.MULTILINE | re.DOTALL)
                if prereq_m:
                    prereq_line = prereq_m.group(1).replace('\n', ' ').strip()
                unloc_m = re.search(r'^\*\*Unlocks:\*\*\s*(.*?)(?=\n\n|> |\n### |\n## |\Z)', rest, re.MULTILINE | re.DOTALL)
                if unloc_m:
                    unlocks_line = unloc_m.group(1).replace('\n', ' ').strip()

                # Description: between Prerequisites and Unlocks (single paragraph usually)
                after_prereq = rest
                if prereq_m:
                    after_prereq = rest[prereq_m.end():]
                # First non-empty line that isn't **Unlocks:**
                lines = after_prereq.split('\n')
                desc_parts = []
                for line in lines:
                    line = line.strip()
                    if line.startswith('**Unlocks:**'):
                        break
                    if line.startswith('>'):
                        continue
                    if line and not line.startswith('**'):
                        desc_parts.append(line)
                        break  # one paragraph
                    if line and line.startswith('**') and 'Unlocks' not in line:
                        continue
                desc = ' '.join(desc_parts).strip() if desc_parts else ""

                raw_techs.append({
                    "branch": category,
                    "tier": tier_num,
                    "name": name_line,
                    "prereq_line": prereq_line,
                    "description": desc,
                    "unlocks": unlocks_line,
                })

    # Build name -> id (display name for matching; use normalized name for id)
    name_to_id: dict[str, str] = {}
    for t in raw_techs:
        clean = re.sub(r'^\[Path [AB]\]\s*', '', t["name"])
        clean = re.sub(r'^\[Shared\]\s*', '', clean)
        clean = re.sub(r'\s*\*\(Cross-Branch Gate[^)]*\)\*', '', clean)
        clean = re.sub(r'\s*\(Cross-Branch Gate prerequisite\)', '', clean)
        clean = clean.strip()
        tid = tech_id(clean)
        name_to_id[clean] = tid
        name_to_id[t["name"].strip()] = tid

    # Add common alternates from doc (e.g. "Psionic Ore Apps" in summary table)
    for t in raw_techs:
        n = t["name"].strip()
        clean = re.sub(r'^\[Path [AB]\]\s*', '', n)
        clean = re.sub(r'^\[Shared\]\s*', '', clean)
        clean = re.sub(r'\s*\*\([^)]*\)\*', '', clean).strip()
        tid = tech_id(clean)
        name_to_id[clean] = tid
        # Short form
        if "Psionic Ore Applications" in clean:
            name_to_id["Psionic Ore Applications"] = tid
            name_to_id["Psionic Ore Apps"] = tid

    # Build final tech list with resolved prerequisites
    result = []
    for t in raw_techs:
        name_clean = re.sub(r'^\[Path [AB]\]\s*', '', t["name"])
        name_clean = re.sub(r'^\[Shared\]\s*', '', name_clean)
        name_clean = re.sub(r'\s*\*\(Cross-Branch Gate[^)]*\)\*', '', name_clean)
        name_clean = re.sub(r'\s*\(Cross-Branch Gate prerequisite\)', '', name_clean)
        name_clean = name_clean.strip()

        tid = tech_id(name_clean)
        prereq_names = parse_prereq_line(t["prereq_line"])
        prereq_ids = resolve_prereqs(prereq_names, name_to_id)

        entry = {
            "id": tid,
            "name_key": name_clean,
            "category": t["branch"],
            "tier": t["tier"],
            "cost": cost_for_tier(t["tier"]),
            "prerequisites": prereq_ids,
            "description": t["description"] or "No description.",
        }
        if t.get("unlocks"):
            entry["unlocks"] = [t["unlocks"]]  # single string for now; could split by comma
        result.append(entry)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent="\t", ensure_ascii=False)

    print(f"Wrote {len(result)} techs to {out_path}")
    # Sanity: count by branch
    by_branch = {0: 0, 1: 0, 2: 0}
    for e in result:
        by_branch[e["category"]] += 1
    print(f"  Physical: {by_branch[0]}, Social: {by_branch[1]}, Xenological: {by_branch[2]}")


if __name__ == "__main__":
    main()
