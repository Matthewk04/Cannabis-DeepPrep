#!/usr/bin/env python3
"""
03_group_participants.py
────────────────────────
Reads group labels from ds000174/participants.tsv and selects prototype subset.
 
ds000174 uses:
  - Numeric IDs: sub-101, sub-103, etc.
  - Group column in participants.tsv: "CB" (cannabis) vs "HC" (healthy control)
 
Outputs:
  outputs/analysis/groups.csv
  outputs/analysis/group_meta.json
  outputs/analysis/pilot_subjects.txt
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
N_PER_GROUP = 5   # ← change to 5, 10, 20 when scaling up
 
# ── Load participants.tsv ─────────────────────────────────────────────────────
tsv_path = BIDS_DIR / "participants.tsv"
if not tsv_path.exists():
    print(f"❌ participants.tsv not found: {tsv_path}")
    print("   Run: bash scripts/01_download_data.sh")
    raise SystemExit(1)
 
df = pd.read_csv(tsv_path, sep="\t")
print(f"[groups] {len(df)} total subjects found in participants.tsv")
print(f"[groups] Columns: {list(df.columns)}")
 
# ── Map group labels from participants.tsv ────────────────────────────────────
# ds000174 uses "CB" for cannabis users, "HC" for healthy controls
 
group_col = next(
    (c for c in ["group", "diagnosis", "cannabis_group", "condition"]
     if c in df.columns), None
)
 
if group_col:
    print(f"[groups] Found group column: '{group_col}'")
    print(f"[groups] Unique values: {df[group_col].unique()}")
    
    # Map CB → heavy, HC → control
    def map_group(val):
        val_str = str(val).strip().upper()
        if val_str == "CB" or "CANNABIS" in val_str or "USER" in val_str:
            return "heavy"
        elif val_str == "HC" or "CONTROL" in val_str or "HEALTHY" in val_str:
            return "control"
        else:
            print(f"[groups] ⚠️  Unrecognized group value: '{val}' — treating as unknown")
            return "unknown"
    
    df["cannabis_group"] = df[group_col].apply(map_group)
    print(f"[groups] Group mapping:")
    print(df.groupby("cannabis_group")["participant_id"].count())
else:
    print("[groups] ❌ No group column found in participants.tsv")
    print(f"[groups]    Available columns: {list(df.columns)}")
    raise SystemExit(1)
 
# ── Prototype subset selection ────────────────────────────────────────────────
heavy_all   = df[df["cannabis_group"] == "heavy"]["participant_id"].tolist()
control_all = df[df["cannabis_group"] == "control"]["participant_id"].tolist()
 
if len(heavy_all) < N_PER_GROUP or len(control_all) < N_PER_GROUP:
    print(f"⚠  Not enough subjects — found {len(heavy_all)} heavy, "
          f"{len(control_all)} controls. Reduce N_PER_GROUP.")
    raise SystemExit(1)
 
# Take the first N from each group (sorted alphabetically for reproducibility)
pilot_heavy   = sorted(heavy_all)[:N_PER_GROUP]
pilot_control = sorted(control_all)[:N_PER_GROUP]
pilot_all     = pilot_heavy + pilot_control
 
print()
print(f"[groups] ── Prototype subset ({N_PER_GROUP} + {N_PER_GROUP} = {len(pilot_all)} subjects) ──")
print(f"[groups]   Heavy users (CB):  {pilot_heavy}")
print(f"[groups]   Controls (HC):     {pilot_control}")
print()
print(f"[groups]   Full dataset has {len(heavy_all)} CB + "
      f"{len(control_all)} HC — increase N_PER_GROUP when scaling up.")
 
# ── Save outputs ──────────────────────────────────────────────────────────────
# groups.csv — full dataset with labels
out_cols = ["participant_id", "cannabis_group"]
for opt in ["age at baseline", "gender", "cudit total baseline"]:
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
    "prototype_mode":   N_PER_GROUP < 10,
    "full_heavy":       heavy_all,
    "full_controls":    control_all,
}
with open(OUT_DIR / "group_meta.json", "w") as fh:
    json.dump(meta, fh, indent=2)
 
# pilot_subjects.txt — one ID per line (strip "sub-" prefix for DeepPrep)
pilot_txt = OUT_DIR / "pilot_subjects.txt"
pilot_txt.write_text("\n".join(str(s).replace("sub-", "") for s in pilot_all) + "\n")
 
print(f"[groups] ✅ Saved:")
print(f"         outputs/analysis/groups.csv")
print(f"         outputs/analysis/group_meta.json")
print(f"         outputs/analysis/pilot_subjects.txt")
print()
if N_PER_GROUP < 10:
    print("[groups] ⚠  Prototype mode: Small sample gives low statistical power.")
    print("         Effect sizes (Cohen's d) are most informative at n<10/group.")
print()
print("[groups] Next: bash scripts/02_run_deepprep_anat.sh --pilot")
