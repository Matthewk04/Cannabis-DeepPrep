# Cannabis MRI Study Using DeepPrep

**Comparing Brain Structural Changes in Heavy vs. Non-Cannabis Users via Accelerated Neuroimaging Preprocessing**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![DeepPrep](https://img.shields.io/badge/DeepPrep-25.1.0-blue)](https://deepprep.readthedocs.io/)
[![Dataset](https://img.shields.io/badge/Dataset-OpenNeuro%20ds000174-green)](https://openneuro.org/datasets/ds000174)

---

## Overview

This repository contains the analysis pipeline for comparing brain structural measures between heavy cannabis users and non-using controls using the [DeepPrep](https://github.com/pBFSLab/DeepPrep) neuroimaging preprocessing framework. DeepPrep leverages GPU-accelerated deep learning (FastSurferCNN, FastCSR, SUGAR, SynthMorph) to provide 7×+ faster preprocessing than traditional FreeSurfer pipelines while maintaining accuracy and robustness.

The pipeline uses a **longitudinal change-score** design: each subject is scanned at baseline (BL) and ~3-year follow-up (FU), and the analysis compares cannabis-related *change* in regional brain measures rather than cross-sectional differences. This is more statistically powerful at small sample sizes because each subject acts as their own control.

### Key Features

- **Reproducible** — BIDS-compliant dataset, containerized preprocessing (Docker), version-controlled analysis code.
- **Single-node** — Runs on one Ubuntu 22.04 machine with an NVIDIA GPU. No cluster orchestration required.
- **Scalable** — Pilot mode (n=5/group) scales to the full dataset (n=20 heavy / n=22 control) with one config change.
- **Robust to known pitfalls** — Handles voxel-size mismatch between sessions, AWS S3 incremental sync (fixes openneuro-py partial-download bug), post-hoc `mri_segstats` for missing aseg.stats.

---

## Headline Result (Pilot, n=5/group)

In the pilot run, the most pronounced longitudinal effect was a **blunted growth of the Left Putamen** in heavy cannabis users over 3 years:

| Region            | Heavy %Δ | Control %Δ | Cohen's d | p (uncorrected) |
|-------------------|---------:|-----------:|----------:|----------------:|
| **Left Putamen**  |   +2.3 % |    +4.9 %  | **−1.53** |     **0.043**   |
| Right Putamen     |   +5.3 % |    +3.4 %  |     +1.17 |       0.116     |
| Right Amygdala    |  +20.5 % |   +11.9 %  |     +1.06 |       0.144     |
| Right Insula thk  |  −11.3 % |    −9.1 %  |     −0.97 |       0.167     |

Three additional regions reached **|d| ≥ 0.8** ("large") effect sizes. None survived FDR correction at this pilot scale — see [Sample Size & Power](#sample-size--power) below. The full result set is in [`outputs/analysis/structural/longitudinal_change.csv`](outputs/analysis/structural/longitudinal_change.csv).

---

## Project Structure

```
Cannabis-DeepPrep/
├── scripts/                                # Pipeline scripts (run in order)
│   ├── 00_setup.sh                         # Single-node Docker + NVIDIA + DeepPrep install
│   ├── 01_download_data.sh                 # AWS S3 sync + integrity check + tsv fix
│   ├── 02_run_deepprep_anat.sh             # Structural preprocessing (per-subject, per-session)
│   ├── 02_run_deepprep_bold.sh             # fMRI preprocessing (placeholder — future work)
│   ├── 03_group_participants.py            # Pilot subject selection + group assignment
│   ├── 04_structural_analysis_longitudinal.py  # PRIMARY analysis: BL→FU change-score comparison
│   ├── 04_functional_analysis.py           # fMRI analysis (placeholder — future work)
│   ├── 05_visualize_longitudinal.py        # Forest plot, trajectories, box plots, summary table
│   ├── fix_participants_tsv.py             # Helper: add `sub-` prefix to participants.tsv
│   ├── generate_aseg.sh                    # Helper: post-hoc mri_segstats for missing aseg.stats
│   └── verify_gpu.sh                       # GPU + Docker + DeepPrep image sanity check
├── notebook/                               # FABRIC multi-node cluster workflow (see below)
│   └── Cannabis_DeepPrep_Cluster.ipynb     # End-to-end notebook: provisions cluster, runs pipeline in parallel
├── data/
│   ├── bids/
│   │   └── ds000174/                       # OpenNeuro dataset (downloaded by 01_download_data.sh)
│   └── freesurfer/
│       └── license.txt                     # FreeSurfer license (user-supplied, gitignored)
├── outputs/
│   ├── deepprep/                           # DeepPrep derivatives (gitignored, large)
│   │   ├── Recon/sub-NNN_ses-XX/
│   │   │   ├── stats/                      # aseg.stats, lh.aparc.stats, rh.aparc.stats
│   │   │   ├── surf/                       # Cortical surface meshes
│   │   │   └── mri/                        # Volumetric images (T1w, aseg, brainmask)
│   │   ├── QC/                             # HTML quality control reports
│   │   └── WorkDir/                        # Nextflow temporary work
│   ├── analysis/
│   │   ├── group_meta.json                 # Pilot group assignments
│   │   ├── pilot_subjects.txt              # Newline list of subject numbers
│   │   ├── groups.csv                      # participant_id → heavy/control
│   │   └── structural/                     # Statistical results (CSVs tracked in git)
│   │       ├── longitudinal_change.csv             ← PRIMARY RESULT
│   │       ├── group_comparison_ses-BL.csv
│   │       ├── group_comparison_ses-FU.csv
│   │       └── subject_features_all.csv
│   └── figures/                            # Generated plots (gitignored, large)
│       ├── 01_forest_plot.png
│       ├── 02_trajectories.png
│       ├── 03_pct_change.png
│       ├── 04_boxplots.png
│       └── 05_summary_table.png
├── logs/                                   # Timestamped DeepPrep logs (gitignored)
├── .gitignore
├── LICENSE
└── README.md
```

---

## Dataset

**[ds000174](https://openneuro.org/datasets/ds000174)** — T1-weighted longitudinal MRI of cannabis users.

| Attribute              | Value                                       |
|------------------------|---------------------------------------------|
| Heavy cannabis users   | N = 20                                      |
| Non-using controls     | N = 22                                      |
| Sessions               | Baseline (BL) + 3-year follow-up (FU)       |
| Scanner                | 3 T Philips Intera                          |
| Sequence (T1w TFE)     | TR/TE/FA: 9.0 ms / 3.5 ms / 8°              |
| Voxel size (BL / FU)   | 1.0 × 1.0 × 1.0 mm³ / 0.875 × 1.2 × 0.875 mm³ |

> ⚠️ **Note**: ds000174 contains only structural MRI (T1w). For functional connectivity analysis, substitute a BIDS dataset with BOLD data.

---

## Quick Start

### Prerequisites

- **OS** — Ubuntu 22.04 LTS
- **GPU** — NVIDIA RTX 6000 / A100 / 4090 / 3090 (or T4 / V100; CPU fallback is much slower)
- **Docker** — ≥ 20.10 with NVIDIA Container Toolkit
- **RAM** — ≥ 16 GB (32 GB recommended)
- **Disk** — ≥ 100 GB free
- **FreeSurfer license** — free registration at https://surfer.nmr.mgh.harvard.edu/registration.html

### Installation

```bash
# 1. Clone
git clone https://github.com/Matthewk04/Cannabis-DeepPrep.git
cd Cannabis-DeepPrep

# 2. Install full software stack (Java 17, NVIDIA driver, Docker, DeepPrep, Nextflow, Python)
sudo bash scripts/00_setup.sh

# 3. Drop in your FreeSurfer license
cp /path/to/your/license.txt data/freesurfer/license.txt

# 4. Verify GPU + Docker pipeline
bash scripts/verify_gpu.sh
```

### Running the Pilot (n=5/group, both sessions)

```bash
# 1. Download ds000174 and verify integrity
bash scripts/01_download_data.sh

# 2. Select pilot subjects with valid T1w in both sessions
python3 scripts/03_group_participants.py

# 3. Preprocess all pilot subjects, both BL and FU
#    (~40 min/session on RTX 6000 → ~13 hr for 10 subjects × 2 sessions)
bash scripts/02_run_deepprep_anat.sh --pilot

# 4. Generate aseg.stats (DeepPrep doesn't run mri_segstats automatically)
bash scripts/generate_aseg.sh

# 5. Run longitudinal change-score analysis
python3 scripts/04_structural_analysis_longitudinal.py

# 6. Generate publication-quality figures
python3 scripts/05_visualize_longitudinal.py
```

**Outputs**:
- `outputs/analysis/structural/longitudinal_change.csv` — primary result (effect sizes per ROI)
- `outputs/analysis/structural/group_comparison_ses-{BL,FU}.csv` — cross-sectional comparisons
- `outputs/analysis/structural/subject_features_all.csv` — per-subject BL / FU / change values
- `outputs/figures/01_forest_plot.png` … `05_summary_table.png`

### Running on a Single Subject

```bash
# Both sessions
bash scripts/02_run_deepprep_anat.sh sub-101

# Only baseline
bash scripts/02_run_deepprep_anat.sh sub-101 BL

# Only follow-up
bash scripts/02_run_deepprep_anat.sh sub-101 FU
```

### Scaling to the Full Dataset

The pipeline scales linearly. To run the full dataset (n=20 heavy, n=22 control):

```bash
N_PER_GROUP=22 python3 scripts/03_group_participants.py
bash scripts/02_run_deepprep_anat.sh --pilot   # processes everyone in pilot_subjects.txt
```

Expect ~75-85 hours of single-node GPU time for ~84 (subject, session) jobs.

---

## FABRIC Cluster Notebook

The `notebook/Cannabis_DeepPrep_Cluster.ipynb` Jupyter notebook is an alternative end-to-end workflow that provisions a multi-node GPU cluster on the [NSF FABRIC testbed](https://portal.fabric-testbed.net/) and runs the same DeepPrep pipeline in parallel across worker nodes. It produces the same outputs as the single-node scripts (`Recon/`, `aseg.stats`, `longitudinal_change.csv`, the five figures), just much faster on large jobs.

### When to Use the Notebook vs. Single-Node Scripts

| You should use…              | Why                                                                                         |
|------------------------------|---------------------------------------------------------------------------------------------|
| **Single-node scripts**      | You have one workstation/server with an NVIDIA GPU. Running ≤ 10 subjects. No FABRIC access.|
| **FABRIC cluster notebook**  | You need to scale to 20+ subjects, want 2-3× wall-clock speedup, or you're producing a reproducible cyberinfrastructure demo. |

For the n=10 pilot, the notebook finishes in about **4 hours** wall-clock vs. **~13 hours** on a single RTX 6000 — roughly a **2.5× speedup** from spreading BL and FU jobs across 3 worker GPUs.

### What the Notebook Does Differently

The notebook (58 cells) automates everything the single-node scripts assume is already done. The key differences:

| Step                          | Single-node scripts                         | Cluster notebook                                                              |
|-------------------------------|---------------------------------------------|-------------------------------------------------------------------------------|
| **Compute provisioning**      | You SSH into one machine yourself.          | `fablib.new_slice()` provisions 4 nodes (1 master + 3 GPU workers) at a chosen FABRIC site. |
| **Networking**                | One host's networking is already set up.    | Configures NAT64 for IPv6-only nodes, builds an internal cluster subnet, distributes SSH keys for passwordless inter-node access. |
| **Software install**          | `00_setup.sh` runs once locally.            | Same setup script is uploaded and executed in parallel on every node.         |
| **Dataset distribution**      | Local disk; one copy.                       | Downloaded once on Node2, then rsync'd to all workers; FreeSurfer license distributed. |
| **Per-subject processing**    | One `02_run_deepprep_anat.sh` invocation per subject, sequential. | Each worker is assigned a subset of subjects and runs `02_run_deepprep_session.sh BL` and `... FU` in parallel. The launcher uses `setsid` + `disown` to fully detach from SSH so paramiko buffers don't fill up and hang. |
| **Output consolidation**      | Outputs already on local disk.              | After processing, runs `chown -R ubuntu` on each worker (Docker writes as root), then rsyncs all `Recon/`, `QC/`, and `stats/` to Node2 for analysis. |
| **Result download**           | Files already local.                        | Cell 20 copies `longitudinal_change.csv`, `subject_features_all.csv`, and the five PNGs from Node2 back to the FABRIC JupyterHub workspace. |
| **Cleanup**                   | N/A.                                        | Cell 22 has a commented-out `slice.delete()` for releasing FABRIC resources after the run. |

The actual DeepPrep invocation, voxel-mismatch session-hiding workaround, post-hoc `mri_segstats`, and longitudinal analysis logic are **identical** to the single-node version — they're the same scripts, just run on remote workers.

### Prerequisites for the Notebook

- **FABRIC account** — apply at https://portal.fabric-testbed.net/. Need a project with sufficient core-hours and GPU allocations.
- **fablib configured** — your FABRIC bastion key, sliver key, and `fabric_rc` set up locally (or in JupyterHub's `~/.fabric/`).
- **JupyterHub or local Python** — with `fabrictestbed-extensions` installed.
- **FreeSurfer license** — the notebook uploads it to Node2 from a local path you set in Cell 1.

### Running the Notebook

1. Open `notebook/Cannabis_DeepPrep_Cluster.ipynb` in JupyterHub (or a local Jupyter with fablib).
2. Edit **Cell 1** (Configuration):

   ```python
   SLICE_NAME    = 'Cannabis_DeepPrep'
   SITE          = 'CERN'        # or any FABRIC site with GPU resources
   N_WORKERS     = 3             # 1-4 GPU workers
   DATASET_ID    = 'ds000174'
   N_PER_GROUP   = 5             # bump to 22 for the full dataset
   FS_LICENSE    = '/home/fabric/work/license.txt'  # your local FS license path
   ```

3. Run cells **1–10** to provision the cluster, install the software stack, and download/distribute the dataset. (~30 min the first time; idempotent on re-run.)
4. Run **Cell 11** to validate everything with a single-subject pilot test (~10 min).
5. Run **Cells 12–17** for the parallel processing (~3-4 hr for n=10, longer for full dataset).
6. Run **Cells 18–21** for analysis, figures, and download to the FABRIC workspace.
7. Optional: **Cell 22** deletes the slice when you're done (uncomment the `slice.delete()` line).

### Reconnecting After Closing the Notebook

The notebook is robust to closure — FABRIC slice state and node disk state both persist when you close JupyterHub, even though the in-memory Python state is lost. To resume:

1. Run cells **1, 2, 3** in order. Cell 3 detects the existing slice via `fablib.get_slice(SLICE_NAME)`.
2. Run **Cell 13** to rebuild the worker `assignments` dict from `group_meta.json` on Node2.
3. Skip ahead to whichever cell you were working on. Earlier cells are idempotent so re-running them is safe.

### Notebook ↔ Scripts Equivalence

The notebook embeds the same script content the `scripts/` directory ships:

| Notebook cell                             | Equivalent file in `scripts/`                                                               |
|-------------------------------------------|---------------------------------------------------------------------------------------------|
| Cell 7 (`DEEPPREP_SETUP_SCRIPT`)          | `00_setup.sh` (with extra cluster-distribution logic)                                       |
| Cells 9, 9.1, 9.2 (download + verify + tsv fix) | `01_download_data.sh` + `fix_participants_tsv.py`                                       |
| Cell 10 (`GROUP_PARTICIPANTS_SCRIPT`)     | `03_group_participants.py`                                                                  |
| Cell 12 (`PROCESSING_SCRIPT`)             | `02_run_deepprep_anat.sh` (cluster version takes assignments via `ASSIGNED_SUBJECTS` env)   |
| Cell 16 (`GENERATE_ASEG_SCRIPT`)          | `generate_aseg.sh`                                                                          |
| Cell 18 (`ANALYSIS_SCRIPT`)               | `04_structural_analysis_longitudinal.py`                                                    |
| Cell 19 (`VIZ_SCRIPT`)                    | `05_visualize_longitudinal.py`                                                              |

If you want to inspect or modify the logic, **edit the script in `scripts/` and re-run the corresponding cell** — both are kept in sync.

---

## Methods

### Preprocessing — DeepPrep 25.1.0

| Module        | Function                              | Time on RTX 6000 |
|---------------|---------------------------------------|-----------------:|
| FastSurferCNN | Brain tissue segmentation             |        ~3 min    |
| FastCSR       | Cortical surface reconstruction       |        ~4 min    |
| SUGAR         | Surface registration → fsaverage      |        ~2 min    |
| SynthMorph    | Spatial normalization → MNI152        |        ~1 min    |

Key invocation parameters (set automatically by `02_run_deepprep_anat.sh`):

```bash
--anat_only              # Structural preprocessing only
--participant_label NNN  # One subject at a time (DeepPrep limitation)
--fs_license_file ...    # FreeSurfer license
--cpus 8 --memory 12     # Per-container resource limits
--skip_bids_validation   # We've already verified upstream
```

### Statistical Analysis

The analysis script computes both cross-sectional and longitudinal comparisons.

**Cross-sectional** (per session): Welch's t-test on regional volumes between heavy and control groups at BL and FU separately. Outputs to `group_comparison_ses-{BL,FU}.csv`.

**Longitudinal** (primary): for each subject, compute Δ = FU − BL per ROI; then Welch's t-test on Δ between groups. Outputs to `longitudinal_change.csv`.

| Step             | Method                                           |
|------------------|--------------------------------------------------|
| Test             | Welch's t-test (does not assume equal variances) |
| Effect size      | Cohen's d (small 0.2, medium 0.5, large 0.8)     |
| Multiple tests   | Benjamini–Hochberg FDR (q < 0.05)                |

**ROIs** (cannabis-relevant a priori regions):

- **Subcortical** (`aseg.stats`): hippocampus, amygdala, caudate, putamen, nucleus accumbens (bilateral)
- **Cortical thickness** (`{lh,rh}.aparc.stats`): superior frontal, rostral middle frontal, superior temporal, insula, caudal anterior cingulate (bilateral)

### Sample Size & Power

The pilot uses n = 5 per group, which gives ~25 % power to detect a large effect (d = 0.8) at α = 0.05. **Effect size, not p-value, is the primary metric at this scale** — uncorrected p-values are reported for transparency, but only an n ≈ 26/group full-dataset run would be powered to survive FDR correction.

| Goal                | n / group | Cluster time (RTX 6000)     |
|---------------------|----------:|-----------------------------|
| Pilot               |         5 | ~13 hr                       |
| 80 % power @ d=0.8  |        26 | ~60 hr                      |
| Full dataset        |     20/22 | ~75-85 hr                   |

---

## GPU vs. CPU Performance

| Hardware                  | Time per session | 1 subject (BL + FU) |
|---------------------------|-----------------:|--------------------:|
| **RTX 6000** (48 GB VRAM) |         ~18 min   |             ~36 min |
| **Tesla T4** (16 GB VRAM) |        ~23 min   |             ~46 min |
| **CPU only** (10 cores)   |       ~125 min   |            ~250 min |

The RTX 6000 is roughly **7× faster** than CPU for this workload.

---

## Multi-Session Handling

ds000174 has BL and FU sessions per subject, with **different voxel sizes** between sessions. DeepPrep 25.1.0 has no `--session_label` flag and will fail with `mri_robust_template` errors if both sessions are present. The runner script works around this by:

1. Hiding the other session (`mv ses-FU/ ses-FU.HIDDEN/`) before each docker run
2. Restoring it afterward via an EXIT trap
3. Renaming the output directory to include the session suffix (`Recon/sub-101` → `Recon/sub-101_ses-BL`)

If your dataset only has one session, the `OTHER_SESSION` hide step is a no-op — the script handles both cases.

---

## Known Pitfalls Handled by This Pipeline

These are issues the pipeline was hardened against during the pilot run. You should not need to deal with them, but documenting them so they don't bite a future replication attempt:

1. **`openneuro-py` produces partial downloads** — the official downloader silently leaves some files as Git LFS pointers (~400-800 KB) instead of the actual binaries. We use `aws s3 sync --no-sign-request` instead, which verifies via checksums.
2. **`participants.tsv` lacks `sub-` prefix** — ds000174 stores bare numeric IDs while BIDS dirs use `sub-NNN`. `fix_participants_tsv.py` patches this idempotently.
3. **DeepPrep doesn't generate `aseg.stats`** — `aseg.mgz` is produced but `mri_segstats` is never invoked. `generate_aseg.sh` runs it post-hoc inside the same container.
4. **Voxel mismatch between sessions** — see "Multi-Session Handling" above.
5. **`nvidia-container-toolkit ≥ 1.18` requires CDI spec** — `00_setup.sh` runs `nvidia-ctk cdi generate` after install.
6. **Java 11 default on Ubuntu 22** — Nextflow needs Java 17. `00_setup.sh` installs OpenJDK 17 and sets it as system default.
7. **Docker outputs are root-owned** — every script that writes to `outputs/deepprep/` ends with `sudo chown -R $USER:$USER`.

---

## Troubleshooting

**`docker run --gpus all` fails with "no known GPU vendor found"**
You're missing the CDI spec. Run:
```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

**DeepPrep fails in `anat_motioncor` with template registration error**
You're trying to process both sessions at once. The runner script (`02_run_deepprep_anat.sh`) handles this — make sure you're using it rather than calling docker directly.

**"File not found" errors in analysis scripts**
Verify aseg.stats files exist:
```bash
ls outputs/deepprep/Recon/sub-101_ses-BL/stats/aseg.stats
```
If missing, run `bash scripts/generate_aseg.sh`.

**`03_group_participants.py` reports "0 subjects with valid data"**
Check T1w file sizes:
```bash
find data/bids/ds000174 -name "*T1w.nii.gz" -size -5M
```
If any T1w files are < 5 MB, re-run `bash scripts/01_download_data.sh` to fix them.

---

## Future Work

The repository scaffolds two BOLD/functional placeholder scripts for an obvious extension to functional connectivity analysis:

- `scripts/02_run_deepprep_bold.sh` — DeepPrep BOLD preprocessing (drop `--anat_only`, add fMRI QC).
- `scripts/04_functional_analysis.py` — Resting-state or task-based connectivity comparison.

Doing this would require swapping in a BIDS dataset with BOLD runs (e.g., an ABCD subset). The structural pipeline is unaffected.

Other natural extensions:

- Scale to the full ds000174 dataset (n = 20/22) for adequate statistical power
- Add cortical-thickness-specific ROIs from the Glasser 360 parcellation
- Apply the same pipeline to other cannabis datasets for replication

---

## Citation

If you use this pipeline, please cite the underlying tools:

```bibtex
@article{deepprep_2025,
  title   = {DeepPrep: An accelerated, scalable, and robust pipeline for neuroimaging preprocessing empowered by deep learning},
  author  = {Ren, Jianxun and An, Ning and Lin, Cong and Zhang, Youjia and others},
  journal = {Nature Methods},
  year    = {2025},
  doi     = {10.1038/s41592-025-02599-1}
}

@article{freesurfer_2012,
  title   = {FreeSurfer},
  author  = {Fischl, Bruce},
  journal = {NeuroImage},
  volume  = {62},
  number  = {2},
  pages   = {774--781},
  year    = {2012}
}
```

Dataset citation (ds000174): see https://openneuro.org/datasets/ds000174.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Acknowledgments

- **Dataset** — ds000174 contributors and OpenNeuro
- **Pipeline** — DeepPrep development team (pBFSLab)
- **References**:
  - Cannabis neuroimaging review: https://pmc.ncbi.nlm.nih.gov/articles/PMC7071506/
  - DeepPrep paper: https://www.nature.com/articles/s41592-025-02599-1
  - OpenNeuro: https://openneuro.org

---

## Contact

Questions? Open an [issue](https://github.com/Matthewk04/Cannabis-DeepPrep/issues) on GitHub.