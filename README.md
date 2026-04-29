# Cannabis fMRI Study Using DeepPrep

**Comparing Brain Structure in Heavy vs. Non-Cannabis Users via Accelerated Neuroimaging Preprocessing**

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Overview

This repository contains the complete analysis pipeline for comparing brain structural measures between heavy cannabis users and non-using controls using the DeepPrep neuroimaging preprocessing framework. DeepPrep leverages GPU-accelerated deep learning (FastSurfer, SynthMorph) to provide 10×+ faster preprocessing than traditional pipelines while maintaining accuracy and robustness.

### Key Features
- **Reproducible**: BIDS-compliant dataset, containerized preprocessing (Docker), version-controlled analysis code
- **Scalable**: Prototype mode (n=5/group) scales to full dataset (n=20/22) with one config change
- **Platform-tested**: Ubuntu 22.04 (Jammy), FABRIC testbed, CPU + GPU workflows
- **Transparent**: All preprocessing parameters, statistical methods, and exclusion criteria documented

---

## Project Structure

```
Cannabis-DeepPrep/
├── scripts/                        # Analysis pipeline scripts
│   ├── 01_download_data.sh
│   ├── 02_run_deepprep_anat.sh     # Multi-session structural preprocessing
│   ├── 02_run_deepprep_bold.sh     # fMRI preprocessing (future)
│   ├── 03_group_participants.py    # Group assignment
│   ├── 04_structural_analysis.py   # Statistical comparison
│   ├── 04_structural_single_subject.py  # Single-subject feature extraction
│   ├── 05_visualize_results.py     # Group-level figures
│   ├── 05_visualize_single_subject.py   # Single-subject QC (optional)
│   └── verify_gpu.sh               # GPU verification utility
├── data/
│   ├── bids/
│   │   └── ds000174/               # OpenNeuro dataset (T1w structural MRI)
│   └── freesurfer/
│       └── license.txt             # FreeSurfer license (required)
├── outputs/
│   ├── deepprep/                   # DeepPrep derivatives
│   │   ├── Recon/                  # FreeSurfer-compatible outputs
│   │   │   └── sub-XXX_ses-YY/     # Per-session results
│   │   │       ├── stats/          # ROI statistics (aseg, aparc)
│   │   │       ├── surf/           # Surface meshes
│   │   │       └── mri/            # Volumetric images
│   │   ├── QC/                     # HTML quality control reports
│   │   └── WorkDir/                # Temporary processing files
│   └── analysis/
│       ├── structural/             # Group comparison results
│       │   ├── group_comparison_ses-BL.csv
│       │   └── subject_features_ses-BL.csv
│       ├── functional/             # fMRI analysis (future)
│       ├── groups.csv              # Group labels (heavy/control)
│       ├── group_meta.json         # Metadata for analysis scripts
│       └── pilot_subjects.txt      # Prototype subject list
├── logs/                           # Timestamped DeepPrep logs
├── .gitignore
├── LICENSE
└── README.md
```

---

## Dataset

**ds000174** — T1-weighted structural MRI study of cannabis users from OpenNeuro

| Attribute | Value |
|---|---|
| Heavy cannabis users | N=20 |
| Non-using controls | N=22 |
| Scanner | 3T Philips Intera |
| Sequence | T1w TFE (TR/TE/FA: 9.0 ms / 3.5 ms / 8°) |
| Voxel size | 0.875 × 1.2 × 0.875 mm³ |

> ⚠️ **Note**: ds000174 contains only structural MRI (T1w). For functional connectivity analysis (Track B), substitute with an fMRI dataset such as ds003702.

---

## Quick Start

### Prerequisites
- **Platform**: Ubuntu 22.04 (tested on FABRIC testbed)
- **GPU**: NVIDIA RTX 6000 (or CPU fallback)
- **Docker**: ≥ 20.10 with NVIDIA Container Toolkit (GPU) or CPU fallback
- **RAM**: ≥ 16 GB (32 GB recommended)
- **Disk**: ≥ 100 GB free
- **FreeSurfer license**: Free registration at https://surfer.nmr.mgh.harvard.edu/registration.html

### Installation

```bash
# Clone the repository
git clone https://github.com/Matthewk04/Cannabis-DeepPrep.git
cd Cannabis-DeepPrep
 
# Install Python dependencies
pip install nilearn nibabel pandas numpy scipy statsmodels matplotlib seaborn
 
# Place your FreeSurfer license
cp /path/to/your/license.txt data/freesurfer/license.txt
 
# Verify GPU is working (RTX 6000)
bash scripts/verify_gpu.sh
```

### Run the Prototype (1 subject, both sessions)
 
```bash
# 1. Download ds000174
bash scripts/01_download_data.sh
 
# 2. Select prototype subject(s)
python3 scripts/03_group_participants.py
 
# 3. Run DeepPrep on one subject (both ses-BL and ses-FU)
#    Expected runtime: ~18 min on RTX 6000 (~9 min per session)
bash scripts/02_run_deepprep_anat.sh sub-101
 
# 4. Extract structural features
python3 scripts/04_structural_single_subject.py
 
# 5. View DeepPrep QC report
firefox outputs/deepprep/QC/sub-101_ses-BL.html
```
### Run Group Comparison (when you have multiple subjects)
 
```bash
# After running DeepPrep on pilot subjects
bash scripts/02_run_deepprep_anat.sh --pilot
 
# Statistical analysis (uses ses-BL by default)
python3 scripts/04_structural_analysis.py
 
# Generate group comparison figures
python3 scripts/05_visualize_results.py
```
 
**Outputs**:
- `outputs/analysis/structural/group_comparison_ses-BL.csv` — t-tests, p-values, Cohen's d
- `outputs/figures/effect_sizes_ses-BL.png` — Forest plot
- `outputs/figures/group_means_ses-BL.png` — Bar chart
---

## Methods

### Preprocessing (DeepPrep 25.1.0)

| Module | Function | Time (GPU) |
|---|---|---|
| FastSurferCNN | Brain tissue segmentation | ~3 min |
| FastCSR | Cortical surface reconstruction | ~4 min |
| SUGAR | Surface registration (→ fsaverage) | ~2 min |
| SynthMorph | Spatial normalization (→ MNI152) | ~1 min |

**Key parameters**:
```bash
--anat_only              # Structural preprocessing only
--session_label BL       # Process baseline session
--fs_license_file        # FreeSurfer license
--cpus 10                # CPU cores
--memory 20              # RAM in GB
--skip_bids_validation   # Bypass BIDS validator
```
 
### Statistical Analysis
- **Session used**: Baseline (ses-BL) for cross-sectional comparison
- **ROIs**: Cannabis-relevant regions from FreeSurfer parcellation:
  - Subcortical: hippocampus, amygdala, caudate, putamen, nucleus accumbens
  - Cortical: superior frontal, rostral middle frontal, superior temporal, insula
- **Test**: Welch's t-test (does not assume equal variances)
- **Correction**: Benjamini-Hochberg FDR (q < 0.05)
- **Effect size**: Cohen's d (small: 0.2, medium: 0.5, large: 0.8)
---
 
## GPU vs. CPU Performance
 
| Hardware | Time per session | Total (1 subject, 2 sessions) |
|---|---|---|
| **RTX 6000** (48 GB VRAM) | ~9 min | ~18 min |
| **Tesla T4** (16 GB VRAM) | ~14 min | ~28 min |
| **CPU** (10 cores) | ~100 min | ~200 min |
 
RTX 6000 is **11× faster** than CPU for this workload.
 
---
 
## Multi-Session Handling
 
ds000174 has **two sessions per subject**. DeepPrep will crash if you don't specify which session to process.
 
### Process both sessions (default):
```bash
bash scripts/02_run_deepprep_anat.sh sub-101
# Processes ses-BL, then ses-FU sequentially
```
 
### Process one session only:
```bash
bash scripts/02_run_deepprep_anat.sh sub-101 BL   # baseline only
bash scripts/02_run_deepprep_anat.sh sub-101 FU   # follow-up only
```
 
### For group analysis:
The analysis script uses **ses-BL (baseline)** by default. To change:
```python
# In 04_structural_analysis.py:
SESSION_FOR_ANALYSIS = "FU"   # change from "BL" to "FU"
```
 
---
 
## DeepPrep Outputs
 
### 1. FreeSurfer-Compatible Derivatives (`outputs/deepprep/Recon/`)
Each processed session produces:
```
sub-101_ses-BL/
├── stats/
│   ├── aseg.stats          # Subcortical volumes
│   ├── brainvol.stats      # Global brain metrics
│   ├── lh.aparc.stats      # Left hemisphere cortical parcellation
│   └── rh.aparc.stats      # Right hemisphere cortical parcellation
├── surf/
│   ├── lh.pial             # Left hemisphere pial surface
│   ├── lh.white            # Left hemisphere white matter surface
│   └── ...
└── mri/
    ├── norm.mgz            # Normalized T1w
    ├── brain.mgz           # Skull-stripped brain
    └── aseg.mgz            # Tissue segmentation
```
 
### 2. Quality Control Reports (`outputs/deepprep/QC/`)
- HTML reports with interactive visualizations
- View in browser: `firefox outputs/deepprep/QC/sub-101_ses-BL.html`
- Includes: segmentation, surfaces, normalization, parcellation
### 3. Analysis Outputs (`outputs/analysis/`)
- `structural/group_comparison_ses-BL.csv` — Statistical results
- `structural/subject_features_ses-BL.csv` — Raw per-subject data
- `groups.csv` — Group assignments (heavy/control)
---
 
## Troubleshooting
 
### GPU not detected
```bash
# Verify GPU
bash scripts/verify_gpu.sh
 
# If it fails at step 4 (Docker nvidia runtime):
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```
 
### DeepPrep crashes during processing
- **Cause**: Likely tried to process both sessions at once
- **Fix**: Run with `--session_label BL` flag (script does this automatically)
### "File not found" errors in analysis scripts
- Check that DeepPrep outputs exist: `ls outputs/deepprep/Recon/sub-101_ses-BL/stats/`
- Verify session name: script looks for `ses-BL` by default
---

## Citation

If you use this pipeline, please cite the DeepPrep paper:
```bibtex
@article{deepprep_2025,
  title={DeepPrep: An accelerated, scalable, and robust pipeline for neuroimaging preprocessing},
  authors={Jianxun Ren, Ning An, Cong Lin, Youjia Zhang, Zhenyu Sun, Wei Zhang, Shiyi Li, Ning Guo, Weigang Cui, Qingyu Hu, Weiwei Wang, Xuehai Wu, Yinyan Wang, Tao Jiang, Theodore D. Satterthwaite, Danhong Wang & Hesheng Liu},
  journal={Nature Methods},
  year={2025},
  doi={10.1038/s41592-025-02599-1}
}
```

---

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgments

- **Dataset**: ds000174 contributors and OpenNeuro
- **Pipeline**: DeepPrep development team (pbFSLab)
- **Platform**: NSF FABRIC testbed
- **References**:
  - Cannabis neuroimaging review: https://pmc.ncbi.nlm.nih.gov/articles/PMC7071506/
  - DeepPrep paper: https://www.nature.com/articles/s41592-025-02599-1
  - OpenNeuro: https://openneuro.org

---

## Contact

Questions? Open an [issue](https://github.com/Matthewk04/Cannabis-DeepPrep/issues) or email the maintainer.
