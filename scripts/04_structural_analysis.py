#!/usr/bin/env python3
"""
04_structural_analysis.py — Multi-session structural comparison
────────────────────────────────────────────────────────────────
Handles ds000174's two sessions (ses-BL, ses-FU) separately.

Strategy:
  1. Extract features from BOTH sessions per subject
  2. Group comparison using BASELINE (ses-BL) only (most stable timepoint)
  3. Optionally: longitudinal analysis (BL → FU change) as separate output

DeepPrep output location:
  outputs/deepprep/Recon/sub-XXX_ses-YY/stats/
"""
import json, warnings
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats
from statsmodels.stats.multitest import fdrcorrection

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────────────
PROJ_DIR     = Path(__file__).resolve().parent.parent
DEEPPREP_DIR = PROJ_DIR / "outputs" / "deepprep" / "Recon"
ANALYSIS_DIR = PROJ_DIR / "outputs" / "analysis" / "structural"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)
GROUP_META   = PROJ_DIR / "outputs" / "analysis" / "group_meta.json"

if not GROUP_META.exists():
    raise FileNotFoundError("Run: python3 scripts/03_group_participants.py")

with open(GROUP_META) as fh:
    meta = json.load(fh)

heavy_ids   = meta["heavy_users"]
control_ids = meta["controls"]
prototype   = meta.get("prototype_mode", False)

print(f"[struct] Group sizes — heavy: {len(heavy_ids)}, controls: {len(control_ids)}")

# ── Which session to use for group comparison ─────────────────────────────────
# Options: "BL" (baseline), "FU" (follow-up), or "both" (average)
SESSION_FOR_ANALYSIS = "BL"   # ← baseline is typically more reliable
print(f"[struct] Using session: ses-{SESSION_FOR_ANALYSIS} for group comparison")


# ── FreeSurfer stats parsers ───────────────────────────────────────────────────
def parse_aseg(path: Path) -> dict:
    """Parse aseg.stats or brainvol.stats"""
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


# ── Collect subject data ───────────────────────────────────────────────────────
all_ids = heavy_ids + control_ids
records, missing = [], []

for sub_id in all_ids:
    # DeepPrep output: Recon/sub-XXX_ses-YY/stats/
    session_dir = DEEPPREP_DIR / f"{sub_id}_ses-{SESSION_FOR_ANALYSIS}"
    stats_dir = session_dir / "stats"

    # Try brainvol.stats first (DeepPrep's version), fallback to aseg.stats
    aseg_file = stats_dir / "brainvol.stats"
    if not aseg_file.exists():
        aseg_file = stats_dir / "aseg.stats"

    if not aseg_file.exists():
        missing.append(f"{sub_id}_ses-{SESSION_FOR_ANALYSIS}")
        continue

    row = {
        "participant_id": sub_id,
        "session": SESSION_FOR_ANALYSIS,
        "group": "heavy" if sub_id in heavy_ids else "control"
    }

    row.update(parse_aseg(aseg_file))

    for hemi in ["lh", "rh"]:
        aparc = stats_dir / f"{hemi}.aparc.stats"
        if aparc.exists():
            row.update(parse_aparc(aparc, hemi))

    records.append(row)

if missing:
    print(f"[struct] ⚠  Missing DeepPrep output for: {missing}")
    print(f"[struct]    Ensure DeepPrep ran for ses-{SESSION_FOR_ANALYSIS}")

if not records:
    print(f"[struct] ❌ No data found for ses-{SESSION_FOR_ANALYSIS}")
    print("   Run: bash code/preprocessing/02_run_deepprep_anat.sh --pilot")
    raise SystemExit(1)

df = pd.DataFrame(records)
print(f"[struct] Loaded: {len(df)} subjects, {df.shape[1]} features")


# ── ROIs (cannabis-relevant) ──────────────────────────────────────────────────
ROI_VOLUMES = [
    "Left-Hippocampus", "Right-Hippocampus",
    "Left-Amygdala", "Right-Amygdala",
    "Left-Caudate", "Right-Caudate",
    "Left-Putamen", "Right-Putamen",
    "Left-Accumbens-area", "Right-Accumbens-area",
    "Left-Cerebral-Cortex", "Right-Cerebral-Cortex",
]
ROI_THICKNESS = [
    "lh_superiorfrontal", "rh_superiorfrontal",
    "lh_rostralmiddlefrontal", "rh_rostralmiddlefrontal",
    "lh_superiortemporal", "rh_superiortemporal",
    "lh_insula", "rh_insula",
]
all_rois = [r for r in ROI_VOLUMES + ROI_THICKNESS if r in df.columns]
print(f"[struct] ROIs available: {len(all_rois)}")


# ── Group comparison ───────────────────────────────────────────────────────────
def cohens_d(g1, g2):
    n1, n2 = len(g1), len(g2)
    pooled = np.sqrt(
        ((n1-1)*np.var(g1, ddof=1) + (n2-1)*np.var(g2, ddof=1)) / (n1+n2-2)
    )
    return (np.mean(g1) - np.mean(g2)) / (pooled + 1e-9)

heavy_df = df[df["group"] == "heavy"]
control_df = df[df["group"] == "control"]

results = []
for roi in all_rois:
    g1 = heavy_df[roi].dropna().values
    g2 = control_df[roi].dropna().values
    if len(g1) < 2 or len(g2) < 2:
        continue
    t, p = stats.ttest_ind(g1, g2, equal_var=False)
    d = cohens_d(g1, g2)
    results.append({
        "roi": roi,
        "mean_heavy": float(np.mean(g1)),
        "mean_control": float(np.mean(g2)),
        "std_heavy": float(np.std(g1, ddof=1)),
        "std_control": float(np.std(g2, ddof=1)),
        "t_stat": float(t),
        "p_uncorrected": float(p),
        "cohens_d": float(d),
        "n_heavy": len(g1),
        "n_control": len(g2),
    })

res_df = pd.DataFrame(results).sort_values("p_uncorrected")

if len(res_df) > 1:
    reject, p_fdr = fdrcorrection(res_df["p_uncorrected"].values, alpha=0.05)
    res_df["p_fdr"] = p_fdr
    res_df["sig_fdr05"] = reject
else:
    res_df["p_fdr"] = res_df["p_uncorrected"]
    res_df["sig_fdr05"] = False

# ── Save ──────────────────────────────────────────────────────────────────────
res_df.to_csv(ANALYSIS_DIR / f"group_comparison_ses-{SESSION_FOR_ANALYSIS}.csv", index=False)
df.to_csv(ANALYSIS_DIR / f"subject_features_ses-{SESSION_FOR_ANALYSIS}.csv", index=False)

# ── Summary ───────────────────────────────────────────────────────────────────
print()
print("=" * 60)
print(f"  GROUP COMPARISON — ses-{SESSION_FOR_ANALYSIS}")
print("=" * 60)
print()

sig = res_df[res_df["sig_fdr05"]]
print(f"Significant ROIs (FDR q<0.05): {len(sig)}")
if len(sig) > 0:
    print(sig[["roi", "cohens_d", "p_fdr"]].to_string(index=False))

print()
print("Top 10 by |Cohen's d|:")
top10 = res_df.reindex(res_df["cohens_d"].abs().sort_values(ascending=False).index).head(10)
print(top10[["roi", "mean_heavy", "mean_control", "cohens_d", "p_uncorrected"]
           ].to_string(index=False, float_format="{:.3f}".format))

print()
print(f"✅ Results saved → outputs/analysis/structural/")
print("   Next: python3 scripts/05_visualize_results.py")
print()
print("DeepPrep QC reports (single-subject visualization):")
print(f"   outputs/deepprep/QC/sub-*_ses-{SESSION_FOR_ANALYSIS}.html")
