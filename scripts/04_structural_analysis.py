#!/usr/bin/env python3
"""
04_structural_analysis.py  — Track A
──────────────────────────────────────
Group comparison of structural MRI derivatives from DeepPrep.
Works for any sample size — prototype (n=5/group) or full (n=20/22).

⚠  With n=5 per group:
   - Welch's t-test is still valid but massively underpowered
   - FDR correction will be very conservative (few tests survive)
   - Cohen's d is the most useful metric at this stage
   - No results should be interpreted as confirmatory

Outputs → outputs/analysis/structural/
  group_comparison_structural.csv   t-stats, p-values, Cohen's d per ROI
  subject_features.csv              raw per-subject measurements
"""
import os, json, warnings
from pathlib import Path

import numpy  as np
import pandas as pd
from scipy  import stats
from statsmodels.stats.multitest import fdrcorrection

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────────────
PROJ_DIR     = Path(__file__).resolve().parent.parent
DEEPPREP_DIR = PROJ_DIR / "outputs" / "deepprep"
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
n_per_group = meta.get("n_per_group", len(heavy_ids))

print(f"[struct] Group sizes — heavy: {len(heavy_ids)}, controls: {len(control_ids)}")
if prototype:
    print(f"[struct] ⚠  PROTOTYPE MODE (n={n_per_group}/group) — results are exploratory only")


# ── FreeSurfer stats parsers ───────────────────────────────────────────────────
def parse_aseg(path: Path) -> dict:
    out = {}
    with open(path) as fh:
        for line in fh:
            if line.startswith("# Measure"):
                parts = line.strip().split(",")
                if len(parts) >= 4:
                    try: out[parts[1].strip()] = float(parts[3].strip())
                    except ValueError: pass
            if line.startswith("#") or not line.strip():
                continue
            cols = line.split()
            if len(cols) >= 5:
                try: out[cols[4]] = float(cols[3])
                except (ValueError, IndexError): pass
    return out

def parse_aparc(path: Path, hemi: str) -> dict:
    out = {}
    with open(path) as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            cols = line.split()
            if len(cols) >= 5:
                try: out[f"{hemi}_{cols[0]}"] = float(cols[4])
                except (ValueError, IndexError): pass
    return out


# ── Collect subject data ───────────────────────────────────────────────────────
all_ids = heavy_ids + control_ids
records, missing = [], []

for sub_id in all_ids:
    stats_dir = DEEPPREP_DIR / sub_id / "stats"
    aseg_file = stats_dir / "aseg.stats"
    if not aseg_file.exists():
        missing.append(sub_id)
        continue
    row = {"participant_id": sub_id,
           "group": "heavy" if sub_id in heavy_ids else "control"}
    row.update(parse_aseg(aseg_file))
    for hemi in ["lh", "rh"]:
        aparc = stats_dir / f"{hemi}.aparc.stats"
        if aparc.exists():
            row.update(parse_aparc(aparc, hemi))
    records.append(row)

if missing:
    print(f"[struct] ⚠  Missing DeepPrep output for: {missing}")
    print(f"[struct]    Run DeepPrep for these subjects first.")
if not records:
    print("[struct] ❌ No data found. Run: bash scripts/02_run_deepprep_anat.sh --pilot")
    raise SystemExit(1)

df = pd.DataFrame(records)
available_heavy   = [s for s in heavy_ids   if s not in missing]
available_control = [s for s in control_ids if s not in missing]
print(f"[struct] Data loaded: {len(available_heavy)} heavy, "
      f"{len(available_control)} controls, {df.shape[1]} features")


# ── ROIs (cannabis-relevant, from literature) ─────────────────────────────────
ROI_VOLUMES = [
    "Left-Hippocampus",    "Right-Hippocampus",
    "Left-Amygdala",       "Right-Amygdala",
    "Left-Caudate",        "Right-Caudate",
    "Left-Putamen",        "Right-Putamen",
    "Left-Accumbens-area", "Right-Accumbens-area",
    "Left-Cerebral-Cortex","Right-Cerebral-Cortex",
    "Left-Cerebral-White-Matter", "Right-Cerebral-White-Matter",
]
ROI_THICKNESS = [
    "lh_superiorfrontal",   "rh_superiorfrontal",
    "lh_rostralmiddlefrontal", "rh_rostralmiddlefrontal",
    "lh_superiortemporal",  "rh_superiortemporal",
    "lh_middletemporal",    "rh_middletemporal",
    "lh_insula",            "rh_insula",
    "lh_parahippocampal",   "rh_parahippocampal",
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

heavy_df   = df[df["group"] == "heavy"]
control_df = df[df["group"] == "control"]

results = []
for roi in all_rois:
    g1 = heavy_df[roi].dropna().values
    g2 = control_df[roi].dropna().values
    if len(g1) < 2 or len(g2) < 2:
        continue
    t, p = stats.ttest_ind(g1, g2, equal_var=False)   # Welch's t-test
    d    = cohens_d(g1, g2)
    results.append({
        "roi":              roi,
        "mean_heavy":       float(np.mean(g1)),
        "mean_control":     float(np.mean(g2)),
        "std_heavy":        float(np.std(g1, ddof=1)),
        "std_control":      float(np.std(g2, ddof=1)),
        "t_stat":           float(t),
        "p_uncorrected":    float(p),
        "cohens_d":         float(d),
        "n_heavy":          len(g1),
        "n_control":        len(g2),
        "effect_size_label": (
            "large"  if abs(d) >= 0.8 else
            "medium" if abs(d) >= 0.5 else
            "small"  if abs(d) >= 0.2 else "negligible"
        ),
    })

res_df = pd.DataFrame(results).sort_values("p_uncorrected")

if len(res_df) > 1:
    reject, p_fdr = fdrcorrection(res_df["p_uncorrected"].values, alpha=0.05)
    res_df["p_fdr"]     = p_fdr
    res_df["sig_fdr05"] = reject
else:
    res_df["p_fdr"] = res_df["p_uncorrected"]
    res_df["sig_fdr05"] = False

# ── Save ──────────────────────────────────────────────────────────────────────
res_df.to_csv(ANALYSIS_DIR / "group_comparison_structural.csv", index=False)
df.to_csv(ANALYSIS_DIR / "subject_features.csv", index=False)

# ── Summary ───────────────────────────────────────────────────────────────────
print()
print("=" * 60)
if prototype:
    print(f"  PROTOTYPE RESULTS  (n={n_per_group}/group — exploratory only)")
else:
    print(f"  RESULTS  (n={len(available_heavy)} heavy, {len(available_control)} controls)")
print("=" * 60)
print()

sig_fdr = res_df[res_df["sig_fdr05"]]
print(f"Significant ROIs (FDR q<0.05): {len(sig_fdr)}")
if prototype and len(sig_fdr) == 0:
    print("  → Expected with n=5/group. Focus on effect sizes below instead.")

print()
print("Top 10 by |Cohen's d| (effect size — most useful metric at small n):")
top10 = res_df.reindex(res_df["cohens_d"].abs().sort_values(ascending=False).index).head(10)
print(top10[["roi", "mean_heavy", "mean_control",
             "cohens_d", "effect_size_label", "p_uncorrected"]
           ].to_string(index=False, float_format="{:.3f}".format))

if prototype:
    print()
    print("⚠  Prototype interpretation guide:")
    print("   |d| ≥ 0.8 → large effect — worth investigating at full n")
    print("   |d| ≥ 0.5 → medium effect — potentially interesting")
    print("   |d| < 0.2 → negligible — probably noise at n=5")
    print()
    print(f"   Full dataset (n=20/22) would give ~{2.2*n_per_group:.0f}x more statistical power.")

print()
print(f"✅ Results saved → outputs/analysis/structural/")
print("   Next: python3 scripts/05_visualize_results.py")
