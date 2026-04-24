#!/usr/bin/env python3
"""
05_visualize_single_subject.py
──────────────────────────────
Single-subject visualization for DeepPrep outputs.

Inputs:
  outputs/analysis/structural/subject_features.csv

Outputs:
  outputs/figures/
    - sub-101_structural_summary.png
    - sub-101_roi_table.csv
"""

from pathlib import Path
import warnings

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────
PROJ_DIR = Path(__file__).resolve().parent.parent
ANA_DIR  = PROJ_DIR / "outputs" / "analysis" / "structural"
FIG_DIR  = PROJ_DIR / "outputs" / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

FEAT_CSV = ANA_DIR / "subject_features.csv"

SUBJECT_ID = "sub-101"

# ── Load data ──────────────────────────────────────────
if not FEAT_CSV.exists():
    raise FileNotFoundError(f"Missing subject_features.csv at {FEAT_CSV}")

df = pd.read_csv(FEAT_CSV)

# Filter single subject
sub_df = df[df["participant_id"] == SUBJECT_ID]

if sub_df.empty:
    raise ValueError(f"No data found for {SUBJECT_ID}")

row = sub_df.iloc[0]

print(f"[viz] Loaded features for {SUBJECT_ID}")
print(f"[viz] Total features: {len(row)}")


# ── Keep only numeric ROI-like features ────────────────
exclude = {"participant_id", "group"}
roi_series = row.drop(labels=[c for c in exclude if c in row.index], errors="ignore")

roi_series = roi_series[pd.to_numeric(roi_series, errors="coerce").notna()]
roi_series = roi_series.astype(float)

# Sort for plotting
roi_series = roi_series.sort_values(ascending=False)


# ── Plot 1: Top ROIs for this subject ──────────────────
top_n = 20
top_rois = roi_series.head(top_n)

fig, ax = plt.subplots(figsize=(12, 6))
ax.bar(range(len(top_rois)), top_rois.values)

ax.set_xticks(range(len(top_rois)))
ax.set_xticklabels(top_rois.index, rotation=45, ha="right", fontsize=8)

ax.set_title(f"{SUBJECT_ID} — Top Structural Features")
ax.set_ylabel("Value")

ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

fig.tight_layout()
fig.savefig(FIG_DIR / f"{SUBJECT_ID}_structural_summary.png", dpi=150)
plt.close(fig)

print(f"[viz] Saved figure → {FIG_DIR / f'{SUBJECT_ID}_structural_summary.png'}")


# ── Save cleaned table ─────────────────────────────────
out_csv = FIG_DIR / f"{SUBJECT_ID}_roi_table.csv"
roi_series.to_frame(name="value").to_csv(out_csv)

print(f"[viz] Saved table → {out_csv}")

print("\n[viz] Done.")
