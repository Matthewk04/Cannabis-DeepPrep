#!/usr/bin/env python3
"""
03_group_participants.py
────────────────────────
Select pilot subjects with VALID T1w data (>5 MB) in BOTH BL and FU sessions,
then split into heavy users (CB) and controls (HC).

Why the size check? The OpenNeuro `openneuro-py` downloader has a known issue
where it silently produces Git-LFS pointer files (~400-800 KB) instead of the
actual binary MRI data (~6-10 MB). Filtering by size catches these so the
pipeline doesn't fail later with cryptic Nextflow errors.

Outputs (in outputs/analysis/):
    group_meta.json     — full pilot metadata (heavy / control lists)
    pilot_subjects.txt  — newline-separated list of subject numbers (no sub- prefix)

Environment variables (optional):
    PROJ_DIR     — project root (default: parent of this script's dir)
    DATASET_ID   — BIDS dataset ID (default: ds000174)
    N_PER_GROUP  — subjects per group (default: 5)
"""
import json
import os
from pathlib import Path

import pandas as pd

PROJ_DIR = Path(os.environ.get("PROJ_DIR", Path(__file__).resolve().parent.parent))
DATASET_ID = os.environ.get("DATASET_ID", "ds000174")
N_PER_GROUP = int(os.environ.get("N_PER_GROUP", "5"))

BIDS_DIR = PROJ_DIR / "data" / "bids" / DATASET_ID
OUT_DIR = PROJ_DIR / "outputs" / "analysis"
OUT_DIR.mkdir(parents=True, exist_ok=True)

MIN_T1W_BYTES = 5 * 1024 * 1024  # 5 MB — filters out Git LFS pointers

df = pd.read_csv(BIDS_DIR / "participants.tsv", sep="\t")
print(f"[groups] {len(df)} subjects in participants.tsv")

# Map CB → heavy, HC → control. Look for the column under any common name.
group_col = next(
    (c for c in ["group", "diagnosis", "cannabis_group"] if c in df.columns),
    None,
)
if group_col is None:
    raise SystemExit(
        f"[groups] ERROR: no group column found. Expected one of "
        f"['group', 'diagnosis', 'cannabis_group']. Got: {list(df.columns)}"
    )

df["cannabis_group"] = df[group_col].apply(
    lambda v: "heavy" if str(v).strip().upper() == "CB"
    else ("control" if str(v).strip().upper() == "HC" else "unknown")
)


def has_valid_session(sid: str, session: str) -> bool:
    """True if subject has a T1w file >= MIN_T1W_BYTES in the given session."""
    anat_dir = BIDS_DIR / sid / f"ses-{session}" / "anat"
    if not anat_dir.exists():
        return False
    return any(t1w.stat().st_size >= MIN_T1W_BYTES for t1w in anat_dir.glob("*T1w.nii.gz"))


def has_both_real_sessions(sid: str) -> bool:
    return has_valid_session(sid, "BL") and has_valid_session(sid, "FU")


df["has_both"] = df["participant_id"].apply(has_both_real_sessions)
valid_df = df[df["has_both"]]
print(f"[groups] {len(valid_df)} subjects have VALID T1w data (>5MB) in both BL and FU")
if len(valid_df) < len(df):
    print(f"[groups] (Skipping {len(df) - len(valid_df)} subjects with missing or undersized T1w files)")

heavy_all = sorted(valid_df[valid_df["cannabis_group"] == "heavy"]["participant_id"].tolist())
ctrl_all = sorted(valid_df[valid_df["cannabis_group"] == "control"]["participant_id"].tolist())
print(f"[groups] Available: {len(heavy_all)} heavy, {len(ctrl_all)} controls")

# Adapt N_PER_GROUP if not enough valid subjects
max_per_group = min(len(heavy_all), len(ctrl_all))
if max_per_group < N_PER_GROUP:
    print(f"\n[groups] WARNING: requested {N_PER_GROUP}/group but only {max_per_group} available.")
    print(f"[groups]    Using N_PER_GROUP={max_per_group} instead.")
    N_PER_GROUP = max_per_group

if N_PER_GROUP < 2:
    raise SystemExit("[groups] Not enough subjects with valid data — re-run S3 sync to get more.")

pilot_heavy = heavy_all[:N_PER_GROUP]
pilot_ctrl = ctrl_all[:N_PER_GROUP]
pilot_all = pilot_heavy + pilot_ctrl

print(f"\n[groups] Selected pilot ({len(pilot_all)} subjects):")
print(f"  Heavy:   {pilot_heavy}")
print(f"  Control: {pilot_ctrl}")

meta = {
    "heavy_users":    pilot_heavy,
    "controls":       pilot_ctrl,
    "n_heavy":        len(pilot_heavy),
    "n_controls":     len(pilot_ctrl),
    "pilot_subjects": pilot_all,
    "n_per_group":    N_PER_GROUP,
    "full_heavy":     heavy_all,
    "full_controls":  ctrl_all,
}
with open(OUT_DIR / "group_meta.json", "w") as f:
    json.dump(meta, f, indent=2)

with open(OUT_DIR / "pilot_subjects.txt", "w") as f:
    for s in pilot_all:
        f.write(s.replace("sub-", "") + "\n")

# Also write groups.csv (handy summary)
groups_df = pd.DataFrame(
    [{"participant_id": s, "group": "heavy"} for s in pilot_heavy]
    + [{"participant_id": s, "group": "control"} for s in pilot_ctrl]
)
groups_df.to_csv(OUT_DIR / "groups.csv", index=False)

print(f"\n[groups] ✅ Saved:")
print(f"   {OUT_DIR / 'group_meta.json'}")
print(f"   {OUT_DIR / 'pilot_subjects.txt'}")
print(f"   {OUT_DIR / 'groups.csv'}")
