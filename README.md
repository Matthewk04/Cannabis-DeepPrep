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
├── code/                           # All analysis code
│   ├── preprocessing/              # Data acquisition + DeepPrep runs
│   │   ├── 00_setup.sh
│   │   ├── 01_download_data.sh
│   │   ├── 02_run_deepprep_anat.sh
│   │   └── 02_run_deepprep_bold.sh
│   ├── analysis/                   # Statistical comparisons
│   │   ├── 03_group_participants.py
│   │   ├── 04_structural_analysis.py
│   │   └── 04_functional_analysis.py
│   └── visualization/              # Figures
│       └── 05_visualize_results.py
├── data/                           # Data (excluded from git via .gitignore)
│   ├── raw/                        # BIDS input datasets (ds000174)
│   ├── derivatives/                # DeepPrep outputs
│   │   └── deepprep/
│   ├── processed/                  # Analysis outputs
│   │   ├── structural/
│   │   ├── functional/
│   │   └── figures/
│   └── freesurfer/
│       └── license.txt             # User-specific (see Setup)
├── docs/                           # Documentation
│   ├── methods.md                  # Detailed methods
│   ├── results.md                  # Results summary (auto-updated)
│   └── figures/                    # Publication-ready figures
├── notebooks/                      # Jupyter notebooks for exploration
│   └── exploratory_analysis.ipynb
├── env/                            # Environment specifications
│   ├── requirements.txt            # pip install -r env/requirements.txt
│   └── conda_environment.yml       # conda env create -f env/conda_environment.yml
├── logs/                           # DeepPrep run logs (timestamped)
├── provision_gpu_node.ipynb        # FABRIC GPU slice provisioning notebook
├── .gitignore
├── LICENSE
└── README.md
```

---

## Dataset

**ds000174** — T1-weighted structural MRI study of cannabis users from OpenNeuro

| Attribute | Value |
|---|---|
| Heavy cannabis users | N=20 (mean age 20.5, SD=2.1) |
| Non-using controls | N=22 (mean age 21.6, SD=2.45) |
| Scanner | 3T Philips Intera |
| Sequence | T1w TFE (TR/TE/FA: 9.0 ms / 3.5 ms / 8°) |
| Voxel size | 0.875 × 1.2 × 0.875 mm³ |

> ⚠️ **Note**: ds000174 contains only structural MRI (T1w). For functional connectivity analysis (Track B), substitute with an fMRI dataset such as ds003702.

---

## Quick Start

### Prerequisites
- **Platform**: Ubuntu 22.04 (tested on FABRIC testbed)
- **Docker**: ≥ 20.10 with NVIDIA Container Toolkit (GPU) or CPU fallback
- **RAM**: ≥ 16 GB (32 GB recommended)
- **Disk**: ≥ 50 GB free
- **FreeSurfer license**: Free registration at https://surfer.nmr.mgh.harvard.edu/registration.html

### Installation

```bash
# Clone the repository
git clone https://github.com/Matthewk04/Cannabis-DeepPrep.git
cd Cannabis-DeepPrep

# Install dependencies (Python 3.10)
pip install -r env/requirements.txt
# OR create a conda environment:
conda env create -f env/conda_environment.yml && conda activate cannabis-deepprep

# Run setup (installs Docker, NVIDIA toolkit if needed, pulls DeepPrep image)
bash code/preprocessing/00_setup.sh

# Place your FreeSurfer license
cp /path/to/your/license.txt data/freesurfer/license.txt
```

### Run the Prototype (10 subjects)

```bash
# Download dataset
bash code/preprocessing/01_download_data.sh

# Select 10-subject prototype subset
python3 code/analysis/03_group_participants.py

# Run DeepPrep (CPU: ~17 hrs, GPU RTX6000: ~2 hrs)
# Recommended: use tmux/screen for long runs
bash code/preprocessing/02_run_deepprep_anat.sh --pilot

# Statistical analysis
python3 code/analysis/04_structural_analysis.py

# Generate figures
python3 code/visualization/05_visualize_results.py
```

**Outputs**: `data/processed/structural/group_comparison_structural.csv`, `data/processed/figures/*.png`

---

## Methods

### Preprocessing (DeepPrep 25.1.0)

| Module | Function | Time (GPU) |
|---|---|---|
| FastSurferCNN | Brain tissue segmentation | ~3 min |
| FastCSR | Cortical surface reconstruction | ~4 min |
| SUGAR | Surface registration (→ fsaverage) | ~2 min |
| SynthMorph | Spatial normalization (→ MNI152) | ~1 min |

**Command**:
```bash
docker run --gpus all --shm-size 8g \
  -v /data/raw:/input:ro \
  -v /data/derivatives:/output \
  pbfslab/deepprep:25.1.0 \
  /input /output participant --anat_only \
  --fs_license_file /license.txt --cpus 10 --memory 20
```

### Statistical Analysis
- **ROIs**: Cannabis-relevant regions (hippocampus, amygdala, striatum, frontal/temporal cortex) from FreeSurfer `aseg.stats` + `aparc.stats`
- **Test**: Welch's t-test (unequal variances)
- **Correction**: Benjamini-Hochberg FDR (q < 0.05)
- **Effect size**: Cohen's d (small: 0.2, medium: 0.5, large: 0.8)

---

## Results

See `docs/results.md` for detailed results (auto-updated after running analysis scripts).

### Prototype Results (n=5/group)
With small sample size, p-values have limited validity. **Cohen's d is the primary metric**:
- |d| ≥ 0.8 → large effect, worth investigating at full n
- |d| ≥ 0.5 → medium effect
- |d| < 0.2 → negligible

Scaling to full dataset (n=20/22) provides ~4× more statistical power.

---

## GPU vs. CPU Performance

| Platform | Time/subject | Total (42 subj) |
|---|---|---|
| **CPU** (10 cores) | ~100 min | ~70 hours |
| **GPU Tesla T4** (16 GB) | ~14 min | ~10 hours |
| **GPU RTX 6000** (48 GB) | ~9 min | ~6 hours |

**Recommendation**: Use FABRIC GPU node (see `provision_gpu_node.ipynb`)

---

## Scaling to Full Dataset

Change one line in `code/analysis/03_group_participants.py`:
```python
N_PER_GROUP = 20   # was 5
```
Then re-run the pipeline from step 3 onward. All scripts automatically adapt.

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
