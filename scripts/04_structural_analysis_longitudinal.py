#!/usr/bin/env python3
"""
04_structural_analysis_longitudinal.py
───────────────────────────────────────
Analyzes both BL and FU sessions and computes longitudinal change scores
(FU − BL) for each subject, then compares those changes between cannabis
users and controls.

This is more powerful than a cross-sectional BL-only comparison because:
  1. Each subject serves as their own control (paired analysis)
  2. Detects cannabis-related CHANGE rather than pre-existing differences
  3. Reduces inter-subject variability that can mask true effects

Outputs:
  outputs/analysis/structural/group_comparison_ses-BL.csv
  outputs/analysis/structural/group_comparison_ses-FU.csv
  outputs/analysis/structural/longitudinal_change.csv  ← KEY RESULT
  outputs/analysis/structural/subject_features_all.csv
"""

import json, warnings
from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats
from statsmodels.stats.multitest import fdrcorrection

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────
PROJ_DIR = Path(__file__).resolve().parent.parent
DEEPPREP_DIR = PROJ_DIR / "outputs" / "deepprep" / "Recon"
ANALYSIS_DIR = PROJ_DIR / "outputs" / "analysis" / "structural"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)
GROUP_META = PROJ_DIR / "outputs" / "analysis" / "group_meta.json"

with open(GROUP_META) as fh:
    meta = json.load(fh)
heavy_ids = meta["heavy_users"]
control_ids = meta["controls"]
all_ids = heavy_ids + control_ids

print(f"[struct] Heavy users: {heavy_ids}")
print(f"[struct] Controls:    {control_ids}")


# ── Improved stats parsers ─────────────────────────────────────────────
def parse_aseg(path: Path) -> dict:
    """Parse aseg.stats — returns subcortical volumes by name."""
    out = {}
    with open(path) as fh:
        for line in fh:
            # # Measure lines (whole-brain measures)
            if line.startswith("# Measure"):
                p = line.strip().split(",")
                if len(p) >= 4:
                    try:
                        out[p[1].strip()] = float(p[3].strip())
                    except ValueError:
                        pass
                continue
            # Skip other comment lines
            if line.startswith("#") or not line.strip():
                continue
            # Data lines: Index SegId NVoxels Volume_mm3 StructName ...
            cols = line.split()
            if len(cols) >= 5:
                try:
                    # cols[3] is volume in mm³, cols[4] is structure name
                    out[cols[4]] = float(cols[3])
                except (ValueError, IndexError):
                    pass
    return out


def parse_aparc(path: Path, hemi: str) -> dict:
    """Parse [lh|rh].aparc.stats — returns cortical thickness by region."""
    out = {}
    with open(path) as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            cols = line.split()
            # Cols: StructName NumVert SurfArea GrayVol ThickAvg ThickStd ...
            if len(cols) >= 5:
                try:
                    # cols[4] is mean thickness in mm
                    out[f"{hemi}_{cols[0]}"] = float(cols[4])
                except (ValueError, IndexError):
                    pass
    return out


# ── Load data for both sessions ────────────────────────────────────────
records = []
missing = []

for sid in all_ids:
    for session in ["BL", "FU"]:
        sd = DEEPPREP_DIR / f"{sid}_ses-{session}" / "stats"
        if not sd.exists():
            missing.append(f"{sid}_ses-{session}")
            continue
        
        row = {
            "participant_id": sid,
            "session": session,
            "group": "heavy" if sid in heavy_ids else "control",
        }
        
        # CRITICAL FIX: Always parse aseg.stats (has regional volumes)
        # brainvol.stats only has summary measures, missing regional ROIs
        aseg_file = sd / "aseg.stats"
        if aseg_file.exists():
            row.update(parse_aseg(aseg_file))
        else:
            print(f"[struct] WARN: aseg.stats missing for {sid}_ses-{session}")
        
        # Cortical parcellation per hemisphere
        for hemi in ["lh", "rh"]:
            aparc = sd / f"{hemi}.aparc.stats"
            if aparc.exists():
                row.update(parse_aparc(aparc, hemi))
        
        records.append(row)

if missing:
    print(f"[struct] Missing data: {missing}")

df = pd.DataFrame(records)
print(f"\n[struct] Loaded: {len(df)} rows ({len(df)/2:.0f} subjects × 2 sessions)")

# Sanity check
n_bl = sum(df["session"] == "BL")
n_fu = sum(df["session"] == "FU")
print(f"[struct]   BL: {n_bl} subjects | FU: {n_fu} subjects")
print(f"[struct]   Available features: {df.shape[1]}")


# ── Define ROIs of interest ────────────────────────────────────────────
ROI_VOLUMES = [
    "Left-Hippocampus", "Right-Hippocampus",
    "Left-Amygdala", "Right-Amygdala",
    "Left-Caudate", "Right-Caudate",
    "Left-Putamen", "Right-Putamen",
    "Left-Accumbens-area", "Right-Accumbens-area",
]
ROI_THICKNESS = [
    "lh_superiorfrontal", "rh_superiorfrontal",
    "lh_rostralmiddlefrontal", "rh_rostralmiddlefrontal",
    "lh_superiortemporal", "rh_superiortemporal",
    "lh_insula", "rh_insula",
    "lh_caudalanteriorcingulate", "rh_caudalanteriorcingulate",
]
all_rois = ROI_VOLUMES + ROI_THICKNESS

# Check which ROIs are actually present
present_rois = [r for r in all_rois if r in df.columns]
missing_rois = [r for r in all_rois if r not in df.columns]
print(f"\n[struct] ROIs found ({len(present_rois)}/{len(all_rois)}):")
print(f"   Present: {present_rois}")
if missing_rois:
    print(f"   MISSING: {missing_rois}")


# ── Helper: Cohen's d ──────────────────────────────────────────────────
def cohens_d(g1, g2):
    g1, g2 = np.asarray(g1), np.asarray(g2)
    n1, n2 = len(g1), len(g2)
    if n1 < 2 or n2 < 2:
        return np.nan
    pooled = np.sqrt(
        ((n1-1)*np.var(g1, ddof=1) + (n2-1)*np.var(g2, ddof=1)) / (n1+n2-2)
    )
    return (np.mean(g1) - np.mean(g2)) / (pooled + 1e-9)


# ── Cross-sectional analyses (BL and FU separately) ───────────────────
def group_compare(df_session, session_label):
    """Run group comparison for one session, return results df."""
    heavy_df = df_session[df_session["group"] == "heavy"]
    ctrl_df = df_session[df_session["group"] == "control"]
    
    results = []
    for roi in present_rois:
        g1 = heavy_df[roi].dropna().values
        g2 = ctrl_df[roi].dropna().values
        if len(g1) < 2 or len(g2) < 2:
            continue
        t, p = stats.ttest_ind(g1, g2, equal_var=False)
        results.append({
            "roi": roi,
            "session": session_label,
            "mean_heavy": float(np.mean(g1)),
            "mean_control": float(np.mean(g2)),
            "std_heavy": float(np.std(g1, ddof=1)),
            "std_control": float(np.std(g2, ddof=1)),
            "cohens_d": float(cohens_d(g1, g2)),
            "t_stat": float(t),
            "p_uncorrected": float(p),
            "n_heavy": len(g1),
            "n_control": len(g2),
        })
    
    res = pd.DataFrame(results)
    if len(res) > 1:
        _, p_fdr = fdrcorrection(res["p_uncorrected"].values, alpha=0.05)
        res["p_fdr"] = p_fdr
        res["sig_fdr05"] = p_fdr < 0.05
    return res.sort_values("p_uncorrected")


print("\n" + "=" * 70)
print(" CROSS-SECTIONAL: ses-BL group comparison")
print("=" * 70)
df_bl = df[df["session"] == "BL"]
res_bl = group_compare(df_bl, "BL")
res_bl.to_csv(ANALYSIS_DIR / "group_comparison_ses-BL.csv", index=False)
top_bl = res_bl.reindex(res_bl["cohens_d"].abs().sort_values(ascending=False).index).head(10)
print(top_bl[["roi", "mean_heavy", "mean_control", "cohens_d", "p_uncorrected"]].to_string(index=False))

print("\n" + "=" * 70)
print(" CROSS-SECTIONAL: ses-FU group comparison")
print("=" * 70)
df_fu = df[df["session"] == "FU"]
res_fu = group_compare(df_fu, "FU")
res_fu.to_csv(ANALYSIS_DIR / "group_comparison_ses-FU.csv", index=False)
top_fu = res_fu.reindex(res_fu["cohens_d"].abs().sort_values(ascending=False).index).head(10)
print(top_fu[["roi", "mean_heavy", "mean_control", "cohens_d", "p_uncorrected"]].to_string(index=False))


# ── LONGITUDINAL CHANGE ANALYSIS (the headline result) ────────────────
print("\n" + "=" * 70)
print(" LONGITUDINAL: BL → FU change comparison (PRIMARY OUTCOME)")
print("=" * 70)

# Pivot so each subject has BL and FU columns side-by-side
# Compute change = FU - BL for each ROI for each subject
change_records = []
for sid in all_ids:
    bl_row = df[(df["participant_id"] == sid) & (df["session"] == "BL")]
    fu_row = df[(df["participant_id"] == sid) & (df["session"] == "FU")]
    if len(bl_row) == 0 or len(fu_row) == 0:
        print(f"[struct] WARNING: {sid} missing BL or FU data, skipping")
        continue
    
    bl_row = bl_row.iloc[0]
    fu_row = fu_row.iloc[0]
    
    rec = {
        "participant_id": sid,
        "group": bl_row["group"],
    }
    for roi in present_rois:
        bl_val = bl_row.get(roi)
        fu_val = fu_row.get(roi)
        if pd.notna(bl_val) and pd.notna(fu_val):
            rec[f"{roi}_BL"] = bl_val
            rec[f"{roi}_FU"] = fu_val
            rec[f"{roi}_change"] = fu_val - bl_val
            rec[f"{roi}_pct_change"] = 100 * (fu_val - bl_val) / bl_val if bl_val != 0 else np.nan
    change_records.append(rec)

change_df = pd.DataFrame(change_records)
change_df.to_csv(ANALYSIS_DIR / "subject_features_all.csv", index=False)

# Compare CHANGE scores between groups
heavy_change = change_df[change_df["group"] == "heavy"]
ctrl_change = change_df[change_df["group"] == "control"]

long_results = []
for roi in present_rois:
    change_col = f"{roi}_change"
    pct_col = f"{roi}_pct_change"
    if change_col not in change_df.columns:
        continue
    
    g1 = heavy_change[change_col].dropna().values
    g2 = ctrl_change[change_col].dropna().values
    if len(g1) < 2 or len(g2) < 2:
        continue
    
    # Independent t-test on change scores
    t, p = stats.ttest_ind(g1, g2, equal_var=False)
    
    # Within-group: did each group change from 0?
    t_heavy_vs_zero, p_heavy_vs_zero = stats.ttest_1samp(g1, 0)
    t_ctrl_vs_zero, p_ctrl_vs_zero = stats.ttest_1samp(g2, 0)
    
    long_results.append({
        "roi": roi,
        "mean_change_heavy": float(np.mean(g1)),
        "mean_change_control": float(np.mean(g2)),
        "std_change_heavy": float(np.std(g1, ddof=1)),
        "std_change_control": float(np.std(g2, ddof=1)),
        "mean_pct_change_heavy": float(np.mean(heavy_change[pct_col].dropna())),
        "mean_pct_change_control": float(np.mean(ctrl_change[pct_col].dropna())),
        "cohens_d_change": float(cohens_d(g1, g2)),
        "t_groups": float(t),
        "p_groups": float(p),
        "p_heavy_vs_zero": float(p_heavy_vs_zero),
        "p_ctrl_vs_zero": float(p_ctrl_vs_zero),
        "n_heavy": len(g1),
        "n_control": len(g2),
    })

long_df = pd.DataFrame(long_results).sort_values("p_groups")
if len(long_df) > 1:
    _, p_fdr = fdrcorrection(long_df["p_groups"].values, alpha=0.05)
    long_df["p_fdr"] = p_fdr
    long_df["sig_fdr05"] = p_fdr < 0.05

long_df.to_csv(ANALYSIS_DIR / "longitudinal_change.csv", index=False)

# Display results
print("\n[Longitudinal change between groups — sorted by effect size]")
top_long = long_df.reindex(long_df["cohens_d_change"].abs().sort_values(ascending=False).index).head(15)
display_cols = [
    "roi",
    "mean_change_heavy",
    "mean_change_control",
    "mean_pct_change_heavy",
    "mean_pct_change_control",
    "cohens_d_change",
    "p_groups",
]
print(top_long[display_cols].to_string(index=False, float_format="{:.3f}".format))

print("\n[Within-group change — did each group change significantly from baseline?]")
within_cols = ["roi", "mean_change_heavy", "p_heavy_vs_zero", "mean_change_control", "p_ctrl_vs_zero"]
sig_changes = long_df[(long_df["p_heavy_vs_zero"] < 0.1) | (long_df["p_ctrl_vs_zero"] < 0.1)]
if len(sig_changes) > 0:
    print(sig_changes[within_cols].to_string(index=False, float_format="{:.4f}".format))
else:
    print("  No within-group changes reached p<0.1 (small sample size)")

print("\n" + "=" * 70)
print(" SUMMARY")
print("=" * 70)
print(f"\nBL-only comparison:        {ANALYSIS_DIR}/group_comparison_ses-BL.csv")
print(f"FU-only comparison:        {ANALYSIS_DIR}/group_comparison_ses-FU.csv")
print(f"LONGITUDINAL CHANGE:       {ANALYSIS_DIR}/longitudinal_change.csv  ← key result")
print(f"Per-subject features:      {ANALYSIS_DIR}/subject_features_all.csv")
print()
print(f"Sample size: n=5 heavy users, n=5 controls — interpret as PILOT effect sizes only.")
print(f"With n=5 per group, even d=0.8 gives only ~25% power to reach p<0.05.")
print(f"Use these results to plan a larger study, NOT for clinical conclusions.")
