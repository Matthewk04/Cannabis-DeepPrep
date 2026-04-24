#!/usr/bin/env python3
"""
04_structural_single_subject.py
────────────────────────────────
Extract structural MRI features for a single subject from DeepPrep outputs.

Input:
  outputs/deepprep/sub-XXX/stats/

Outputs:
  outputs/analysis/structural/subject_features.csv
"""

import warnings
from pathlib import Path
import pandas as pd

warnings.filterwarnings("ignore")

# ── Config ────────────────────────────────────────────────────────────────────
SUBJECT_ID = "sub-101"   # change this as needed

# ── Paths ─────────────────────────────────────────────────────────────────────
PROJ_DIR     = Path(__file__).resolve().parent.parent
DEEPPREP_DIR = PROJ_DIR / "outputs" / "deepprep" / "Recon"
ANALYSIS_DIR = PROJ_DIR / "outputs" / "analysis" / "structural"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)

stats_dir = DEEPPREP_DIR / SUBJECT_ID / "stats"


# ── Parsers ───────────────────────────────────────────────────────────────────
def parse_aseg(path: Path) -> dict:
    out = {}
    with open(path) as fh:
        for line in fh:
            if line.startswith("# Measure"):
                parts = line.strip().split(",")
                if len(parts) >= 4:
                    try:
                        out[parts[1].strip()] = float(parts[3].strip())
                    except ValueError:
                        pass
            if line.startswith("#") or not line.strip():
                continue
            cols = line.split()
            if len(cols) >= 5:
                try:
                    out[cols[4]] = float(cols[3])
                except (ValueError, IndexError):
                    pass
    return out


def parse_aparc(path: Path, hemi: str) -> dict:
    out = {}
    with open(path) as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            cols = line.split()
            if len(cols) >= 5:
                try:
                    out[f"{hemi}_{cols[0]}"] = float(cols[4])
                except (ValueError, IndexError):
                    pass
    return out

# -- ----------------------------------

brainvol_file = stats_dir / "brainvol.stats"

row = {"participant_id": SUBJECT_ID}

if brainvol_file.exists():
    row.update(parse_aseg(brainvol_file))
else:
    print(f"Warning: brainvol.stats missing for {SUBJECT_ID}")

# ── Extract features ──────────────────────────────────────────────────────────
row = {"participant_id": SUBJECT_ID}

# Subcortical volumes
row.update(parse_aseg(brainvol_file))

# Cortical thickness (lh + rh)
for hemi in ["lh", "rh"]:
    aparc_file = stats_dir / f"{hemi}.aparc.stats"
    if aparc_file.exists():
        row.update(parse_aparc(aparc_file, hemi))
    else:
        print(f"Warning: Missing {hemi}.aparc.stats (skipping)")

df = pd.DataFrame([row])

# ── Save ──────────────────────────────────────────────────────────────────────
out_file = ANALYSIS_DIR / "subject_features.csv"
df.to_csv(out_file, index=False)

# ── Summary ───────────────────────────────────────────────────────────────────
print()
print("=" * 60)
print("SINGLE SUBJECT FEATURE EXTRACTION")
print("=" * 60)
print()
print(f"Subject: {SUBJECT_ID}")
print(f"Total features extracted: {df.shape[1] - 1}")  # minus participant_id
print()
print(f"Saved -> {out_file}")
print()
print("Next step:")
print("Run more subjects, then switch back to group analysis script")
