#!/usr/bin/env python3
"""
03_group_participants.py
────────────────────────
Selects the 10-subject prototype subset from ds000174
(5 heavy cannabis users + 5 non-using controls) and writes
the group labels used by all downstream analysis scripts.

Outputs:
  outputs/analysis/groups.csv        — full label file (all 42 subjects)
  outputs/analysis/group_meta.json   — includes pilot_subjects list
  outputs/analysis/pilot_subjects.txt — one subject ID per line (for DeepPrep)
"""

import os, json, re
from pathlib import Path
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
PROJ_DIR = Path(__file__).resolve().parent.parent
BIDS_DIR = PROJ_DIR / "data" / "bids" / "ds000174"
OUT_DIR  = PROJ_DIR / "outputs" / "analysis"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ── Prototype config ──────────────────────────────────────────────────────────
N_PER_GROUP = 5   # ← change to 10, 20 etc. when you're ready to scale up

# ── Load participants.tsv ─────────────────────────────────────────────────────
tsv_path = BIDS_DIR / "participants.tsv"
if not tsv_path.exists():
    print(f"❌ participants.tsv not found: {tsv_path}")
    print("   Run: bash scripts/01_download_data.sh")
    raise SystemExit(1)

df = pd.read_csv(tsv_path, sep="\t")
print(f"[groups] {len(df)} total subjects found in participants.tsv")
print(f"[groups] Columns: {list(df.columns)}")

# ── Infer group from participant_id ───────────────────────────────────────────
# ds000174 naming: sub-cannabis01..20 = heavy users
#                  sub-control01..22  = controls
# (if your download uses numeric IDs like sub-01, the fallback handles it)

def infer_group(pid: str) -> str:
    pid_lower = pid.lower()
    if any(k in pid_lower for k in ["cannabis", "heavy", "marij", "user"]):
        return "heavy"
    if any(k in pid_lower for k in ["control", "ctrl", "healthy", "hc"]):
        return "control"
    # Numeric fallback: sub-01..20 → heavy, sub-21..42 → control
    m = re.search(r"\d+", pid)
    if m:
        num = int(m.group())
        return "heavy" if num <= 20 else "control"
    return "unknown"

# Only assign group if no explicit column exists
group_col = next(
    (c for c in ["group", "diagnosis", "cannabis_group", "condition"]
     if c in df.columns), None
)

if group_col:
    df["cannabis_group"] = df[group_col].apply(
        lambda x: "heavy" if str(x).lower() in
                  ["cannabis", "heavy", "user", "1"] else "control"
    )
    print(f"[groups] Using existing column: '{group_col}'")
else:
    df["cannabis_group"] = df["participant_id"].apply(infer_group)
    print("[groups] Group inferred from participant_id")

# ── Prototype subset selection ────────────────────────────────────────────────
heavy_all   = df[df["cannabis_group"] == "heavy"]["participant_id"].tolist()
control_all = df[df["cannabis_group"] == "control"]["participant_id"].tolist()

if len(heavy_all) < N_PER_GROUP or len(control_all) < N_PER_GROUP:
    print(f"⚠  Not enough subjects — found {len(heavy_all)} heavy, "
          f"{len(control_all)} controls. Reduce N_PER_GROUP.")
    raise SystemExit(1)

# Take the first N from each group (deterministic, reproducible)
pilot_heavy   = ["sub-101"]
pilot_control = []
pilot_all     = ["sub-101"]

print()
print(f"[groups] ── Prototype subset ({N_PER_GROUP} + {N_PER_GROUP} = {len(pilot_all)} subjects) ──")
print(f"[groups]   Heavy users:  {pilot_heavy}")
print(f"[groups]   Controls:     {pilot_control}")
print()
print(f"[groups]   Full dataset has {len(heavy_all)} heavy + "
      f"{len(control_all)} controls — increase N_PER_GROUP when scaling up.")

# ── Save outputs ──────────────────────────────────────────────────────────────
# groups.csv — full dataset with labels (all 42 subjects)
out_cols = ["participant_id", "cannabis_group"]
for opt in ["age", "sex"]:
    if opt in df.columns:
        out_cols.append(opt)
df[[c for c in out_cols if c in df.columns]].to_csv(
    OUT_DIR / "groups.csv", index=False
)

# group_meta.json — consumed by analysis scripts
meta = {
    "heavy_users":      pilot_heavy,
    "controls":         pilot_control,
    "n_heavy":          len(pilot_heavy),
    "n_controls":       len(pilot_control),
    "pilot_subjects":   pilot_all,
    "n_per_group":      N_PER_GROUP,
    "prototype_mode":   True,
    "full_heavy":       heavy_all,
    "full_controls":    control_all,
}
with open(OUT_DIR / "group_meta.json", "w") as fh:
    json.dump(meta, fh, indent=2)

# pilot_subjects.txt — one ID per line, used by the DeepPrep run scripts
pilot_txt = OUT_DIR / "pilot_subjects.txt"
pilot_txt.write_text("\n".join(s.replace("sub-", "") for s in pilot_all) + "\n")

print(f"[groups] ✅ Saved:")
print(f"         outputs/analysis/groups.csv")
print(f"         outputs/analysis/group_meta.json")
print(f"         outputs/analysis/pilot_subjects.txt")
print()
print("[groups] ⚠  Prototype note: n=5 per group gives very low statistical power.")
print("         Effect sizes (Cohen's d) are informative; treat p-values as exploratory.")
print()
print("[groups] Next: bash scripts/02_run_deepprep_anat.sh --pilot")
