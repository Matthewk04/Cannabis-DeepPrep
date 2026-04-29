#!/usr/bin/env python3
"""
04_functional_analysis.py  — Track B
──────────────────────────────────────
Functional connectivity analysis on DeepPrep-preprocessed BOLD data.

Analyses:
  1. Confound regression (motion, WM, CSF, global signal)
  2. Parcellated time-series extraction (Schaefer 200-ROI atlas)
  3. Whole-brain functional connectivity (FC) matrix per subject
  4. Group-level FC comparison: heavy users vs controls
     - ROI-pair t-tests with FDR correction
     - Seed-based connectivity (default: posterior cingulate cortex)
  5. Save FC matrices, group difference map, summary stats

Inputs (from DeepPrep full pipeline):
  outputs/deepprep/sub-XX/func/
    *_task-rest_space-MNI152NLin6Asym_res-02_desc-preproc_bold.nii.gz
    *_task-rest_desc-confounds_timeseries.tsv

NOTE: Update TASK_LABEL below to match your dataset.
"""
import os, json, re, warnings
from pathlib import Path

import numpy  as np
import pandas as pd
from scipy import stats
from statsmodels.stats.multitest import fdrcorrection

warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", category=UserWarning)

try:
    import nibabel as nib
    from nilearn import image, signal, datasets
    from nilearn.maskers import NiftiLabelsMasker
except ImportError:
    print("❌ nilearn/nibabel not installed.")
    print("   Run: pip install nilearn nibabel")
    exit(1)

# ── Configuration ─────────────────────────────────────────────────────────────
PROJ_DIR      = Path(__file__).resolve().parent.parent
DEEPPREP_DIR  = PROJ_DIR / "outputs" / "deepprep"
ANALYSIS_DIR  = PROJ_DIR / "outputs" / "analysis" / "functional"
ANALYSIS_DIR.mkdir(parents=True, exist_ok=True)

TASK_LABEL    = "rest"          # ← edit to match your dataset
SPACE         = "MNI152NLin6Asym"
RES           = "02"
N_PARCELS     = 200             # Schaefer parcellation size

# Confounds to regress out from BOLD signal
CONFOUND_COLS = [
    "trans_x", "trans_y", "trans_z",
    "rot_x",   "rot_y",   "rot_z",
    "white_matter", "csf",
    "global_signal",
    "framewise_displacement",
]

# ── Load groups ───────────────────────────────────────────────────────────────
GROUP_META = PROJ_DIR / "outputs" / "analysis" / "group_meta.json"
if not GROUP_META.exists():
    raise FileNotFoundError("Run: python scripts/03_group_participants.py")

with open(GROUP_META) as fh:
    meta = json.load(fh)
heavy_ids   = meta["heavy_users"]
control_ids = meta["controls"]
all_ids     = heavy_ids + control_ids

# ── Load Schaefer atlas ───────────────────────────────────────────────────────
print(f"[func] Fetching Schaefer {N_PARCELS}-ROI atlas (Yeo 7 networks)...")
atlas       = datasets.fetch_atlas_schaefer_2018(n_rois=N_PARCELS,
                                                  resolution_mm=2)
atlas_img   = atlas.maps
atlas_labels= atlas.labels
print(f"[func] Atlas loaded: {len(atlas_labels)} parcels")

masker = NiftiLabelsMasker(
    labels_img=atlas_img,
    standardize=True,
    t_r=2.0,               # ← update TR if different
    memory_level=1,
    verbose=0,
)

# ── Helper: load confounds ────────────────────────────────────────────────────
def load_confounds(conf_path: Path) -> np.ndarray | None:
    conf_df = pd.read_csv(conf_path, sep="\t")
    avail   = [c for c in CONFOUND_COLS if c in conf_df.columns]
    if not avail:
        return None
    sub_df = conf_df[avail].fillna(0)
    return sub_df.values


# ── Extract time-series per subject ──────────────────────────────────────────
fc_matrices = {}
missing     = []

for sub_id in all_ids:
    func_dir = DEEPPREP_DIR / sub_id / "func"
    if not func_dir.exists():
        missing.append(sub_id)
        continue

    # Find preprocessed BOLD
    bold_files = sorted(func_dir.glob(
        f"*task-{TASK_LABEL}*space-{SPACE}*res-{RES}*preproc_bold.nii.gz"
    ))
    conf_files = sorted(func_dir.glob(
        f"*task-{TASK_LABEL}*confounds_timeseries.tsv"
    ))

    if not bold_files:
        print(f"[func] ⚠ No BOLD found for {sub_id} — skipping")
        missing.append(sub_id)
        continue

    bold_path = bold_files[0]
    conf_mat  = load_confounds(conf_files[0]) if conf_files else None

    print(f"[func] Processing {sub_id} ...", end=" ", flush=True)
    try:
        time_series = masker.fit_transform(
            str(bold_path),
            confounds=conf_mat,
        )
        # Correlation matrix (FC)
        fc = np.corrcoef(time_series.T)
        fc_matrices[sub_id] = fc
        print(f"✓ ({time_series.shape[0]} TRs, {time_series.shape[1]} parcels)")
    except Exception as e:
        print(f"✗ Error: {e}")
        missing.append(sub_id)

if missing:
    print(f"\n[func] ⚠ Subjects with missing/failed data: {missing}")

if not fc_matrices:
    print("[func] ❌ No FC matrices computed. Verify DeepPrep outputs.")
    exit(1)

print(f"\n[func] Computed FC matrices for {len(fc_matrices)} subjects")

# ── Save individual FC matrices ───────────────────────────────────────────────
np.save(ANALYSIS_DIR / "fc_matrices.npy",
        {k: v for k, v in fc_matrices.items()})

# Also save as stacked array
valid_heavy   = [s for s in heavy_ids   if s in fc_matrices]
valid_control = [s for s in control_ids if s in fc_matrices]

fc_heavy   = np.stack([fc_matrices[s] for s in valid_heavy])
fc_control = np.stack([fc_matrices[s] for s in valid_control])

np.save(ANALYSIS_DIR / "fc_heavy.npy",   fc_heavy)
np.save(ANALYSIS_DIR / "fc_control.npy", fc_control)

print(f"[func] Saved FC matrices — heavy: {fc_heavy.shape}, control: {fc_control.shape}")

# ── Group difference: t-test on each ROI pair ─────────────────────────────────
n_rois  = N_PARCELS
t_map   = np.zeros((n_rois, n_rois))
p_map   = np.ones( (n_rois, n_rois))

for i in range(n_rois):
    for j in range(i+1, n_rois):
        g1 = fc_heavy  [:, i, j]
        g2 = fc_control[:, i, j]
        t, p = stats.ttest_ind(g1, g2, equal_var=False)
        t_map[i, j] = t_map[j, i] = t
        p_map[i, j] = p_map[j, i] = p

# FDR correction on upper triangle
upper_idx = np.triu_indices(n_rois, k=1)
p_upper   = p_map[upper_idx]
reject, p_fdr = fdrcorrection(p_upper, alpha=0.05)

p_fdr_map = np.ones((n_rois, n_rois))
p_fdr_map[upper_idx]              = p_fdr
p_fdr_map[upper_idx[1], upper_idx[0]] = p_fdr  # symmetric

np.save(ANALYSIS_DIR / "t_map.npy",     t_map)
np.save(ANALYSIS_DIR / "p_map.npy",     p_map)
np.save(ANALYSIS_DIR / "p_fdr_map.npy", p_fdr_map)

n_sig = int(np.sum(p_fdr < 0.05) // 2)
print(f"\n[func] Significant ROI pairs (FDR q<0.05): {n_sig}")

# ── Seed-based connectivity — Posterior Cingulate Cortex ─────────────────────
# PCC = Schaefer Default Mode hub, frequently implicated in cannabis studies
pcc_label = next((i for i, l in enumerate(atlas_labels)
                  if b"Default" in l and b"PCC" in l), None)
if pcc_label is None:
    # Fallback: use first Default Mode parcel
    pcc_label = next((i for i, l in enumerate(atlas_labels)
                      if b"Default" in l), 0)

pcc_fc_heavy   = fc_heavy  [:, pcc_label, :]
pcc_fc_control = fc_control[:, pcc_label, :]

pcc_t  = stats.ttest_ind(pcc_fc_heavy, pcc_fc_control, equal_var=False).statistic
_, p_pcc_fdr = fdrcorrection(
    stats.ttest_ind(pcc_fc_heavy, pcc_fc_control, equal_var=False).pvalue,
    alpha=0.05
)

pcc_df = pd.DataFrame({
    "parcel_idx":     range(n_rois),
    "parcel_label":   [l.decode() if isinstance(l, bytes) else l
                       for l in atlas_labels],
    "t_stat_pcc":     pcc_t,
    "p_fdr_pcc":      p_pcc_fdr,
    "mean_heavy_pcc": pcc_fc_heavy.mean(axis=0),
    "mean_ctrl_pcc":  pcc_fc_control.mean(axis=0),
}).sort_values("p_fdr_pcc")

pcc_df.to_csv(ANALYSIS_DIR / "pcc_seed_connectivity.csv", index=False)
print(f"[func] PCC seed connectivity saved → pcc_seed_connectivity.csv")
print(f"[func] Top 5 PCC-connected regions (group difference):")
print(pcc_df.head(5)[["parcel_label","t_stat_pcc","p_fdr_pcc"]].to_string(index=False))

print("\n[func] ✅ Functional analysis complete.")
print("[func] Next: python scripts/05_visualize_results.py")
