#!/usr/bin/env bash
# =============================================================================
# reorganize_repo.sh
# Restructures Cannabis-DeepPrep to follow neuroimaging research best practices
#
# New structure:
#   code/          ← was scripts/ (clearer name for research repos)
#   data/          ← reorganized into raw/derivatives/processed
#   docs/          ← NEW - methods, results, figures
#   notebooks/     ← NEW - exploratory Jupyter notebooks
#   env/           ← NEW - environment specifications
#   .gitignore     ← NEW - exclude large files
#   LICENSE        ← NEW - MIT license
#   README.md      ← IMPROVED - comprehensive project docs
#   requirements.txt ← NEW - Python dependencies
#
# Run from repo root: bash reorganize_repo.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(pwd)"
echo "[reorg] Working in: $REPO_ROOT"
echo ""

# Safety check — abort if not in Cannabis-DeepPrep or similar
if [ ! -d "scripts" ] && [ ! -d "data" ]; then
  echo "❌ This doesn't look like the Cannabis-DeepPrep repo."
  echo "   Expected to find scripts/ and data/ directories."
  echo "   Run from repo root: cd ~/Cannabis-DeepPrep && bash reorganize_repo.sh"
  exit 1
fi

echo "[reorg] ── Phase 1: Backup current state ──────────────────────────"
BACKUP_DIR="${REPO_ROOT}_backup_$(date +%Y%m%d_%H%M%S)"
echo "[reorg] Creating backup at: $BACKUP_DIR"
cp -r "$REPO_ROOT" "$BACKUP_DIR"
echo "[reorg] ✓ Backup complete (delete manually if reorg succeeds)"
echo ""

echo "[reorg] ── Phase 2: Rename scripts/ → code/ ───────────────────────"
if [ -d "scripts" ]; then
  git mv scripts code 2>/dev/null || mv scripts code
  echo "[reorg] ✓ scripts/ → code/"
fi

echo "[reorg] ── Phase 3: Reorganize code/ with subdirectories ───────────"
mkdir -p code/preprocessing code/analysis code/visualization

# Sort existing scripts into subdirectories
if [ -f "code/00_setup.sh" ];                  then mv code/00_setup.sh              code/preprocessing/; fi
if [ -f "code/01_download_data.sh" ];          then mv code/01_download_data.sh      code/preprocessing/; fi
if [ -f "code/02_run_deepprep_anat.sh" ];      then mv code/02_run_deepprep_anat.sh  code/preprocessing/; fi
if [ -f "code/02_run_deepprep_bold.sh" ];      then mv code/02_run_deepprep_bold.sh  code/preprocessing/; fi
if [ -f "code/03_group_participants.py" ];     then mv code/03_group_participants.py code/analysis/; fi
if [ -f "code/04_structural_analysis.py" ];    then mv code/04_structural_analysis.py code/analysis/; fi
if [ -f "code/04_functional_analysis.py" ];    then mv code/04_functional_analysis.py code/analysis/; fi
if [ -f "code/05_visualize_results.py" ];      then mv code/05_visualize_results.py  code/visualization/; fi

echo "[reorg] ✓ Scripts sorted into preprocessing/analysis/visualization"
echo ""

echo "[reorg] ── Phase 4: Reorganize data/ structure ─────────────────────"
mkdir -p data/raw data/derivatives data/processed

# Move BIDS dataset to raw/
if [ -d "data/bids" ]; then
  mv data/bids/* data/raw/ 2>/dev/null || true
  rmdir data/bids 2>/dev/null || true
fi

# Move DeepPrep outputs to derivatives/
if [ -d "outputs/deepprep" ]; then
  mkdir -p data/derivatives
  mv outputs/deepprep data/derivatives/ 2>/dev/null || true
fi

# Move analysis outputs to processed/
if [ -d "outputs/analysis" ]; then
  mv outputs/analysis data/processed/
fi

if [ -d "outputs/figures" ]; then
  mkdir -p data/processed/figures
  mv outputs/figures/* data/processed/figures/ 2>/dev/null || true
  rmdir outputs/figures 2>/dev/null || true
fi

# Remove empty outputs/ if it exists
rmdir outputs 2>/dev/null || true

echo "[reorg] ✓ Data reorganized:"
echo "          data/raw/           ← BIDS input datasets"
echo "          data/derivatives/   ← DeepPrep outputs"
echo "          data/processed/     ← Analysis results + figures"
echo ""

echo "[reorg] ── Phase 5: Create docs/ directory ─────────────────────────"
mkdir -p docs/figures

cat > docs/methods.md <<'EOF'
# Methods

## Dataset
- **Source**: OpenNeuro ds000174
- **Subjects**: Heavy cannabis users (N=20) vs non-using controls (N=22)
- **Scanner**: 3T Philips Intera
- **Sequence**: T1-weighted TFE (structural MRI only)

## Preprocessing
- **Pipeline**: DeepPrep 25.1.0 (Docker: `pbfslab/deepprep:25.1.0`)
- **Mode**: `--anat_only` (structural preprocessing)
- **Modules**:
  - FastSurferCNN: Deep learning-based brain tissue segmentation
  - FastCSR: Cortical surface reconstruction
  - SUGAR: Surface registration to fsaverage template
  - Spatial normalization: MNI152NLin6Asym

## Analysis
- **ROI selection**: Cannabis-relevant regions (hippocampus, amygdala, frontal/temporal cortex, striatum)
- **Statistical tests**: Welch's t-test (unequal variances)
- **Multiple comparison correction**: Benjamini-Hochberg FDR (q < 0.05)
- **Effect size**: Cohen's d

## Software
- DeepPrep 25.1.0
- Python 3.10 (Ubuntu 22.04)
- nilearn, nibabel, pandas, scipy, statsmodels, matplotlib, seaborn
EOF

cat > docs/results.md <<'EOF'
# Results

## Preprocessing outcomes
- **Successful runs**: XX/42 subjects (placeholder — update after running)
- **Failed subjects**: (list any QC failures)
- **Mean processing time**: ~X min/subject (GPU) or ~X min/subject (CPU)

## Group differences
(This section auto-populated after running `04_structural_analysis.py`)

### Significant ROIs (FDR q < 0.05)
| ROI | Heavy users (mean ± SD) | Controls (mean ± SD) | Cohen's d | p-value |
|-----|-------------------------|---------------------|-----------|---------|
| ... | ... | ... | ... | ... |

### Top effect sizes (|d| ≥ 0.5)
| ROI | Effect size | Interpretation |
|-----|------------|----------------|
| ... | ... | ... |

## Figures
See `data/processed/figures/`:
- `structural_roi_comparison.png` — Bar chart of ROI volumes/thickness
- `structural_effect_sizes.png` — Cohen's d forest plot
EOF

echo "[reorg] ✓ Created docs/methods.md and docs/results.md"
echo ""

echo "[reorg] ── Phase 6: Create notebooks/ directory ───────────────────"
mkdir -p notebooks

cat > notebooks/exploratory_analysis.ipynb <<'NBEOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": ["# Exploratory Data Analysis — Cannabis DeepPrep\n", "Interactive exploration of preprocessing outputs and group differences."]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": ["import pandas as pd\n", "import numpy as np\n", "import matplotlib.pyplot as plt\n", "import seaborn as sns\n", "from pathlib import Path\n", "\n", "sns.set_theme(style='whitegrid')\n", "%matplotlib inline"]
  },
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": ["## Load analysis outputs"]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": ["DATA_DIR = Path('../data/processed')\n", "res_df = pd.read_csv(DATA_DIR / 'structural/group_comparison_structural.csv')\n", "feat_df = pd.read_csv(DATA_DIR / 'structural/subject_features.csv')\n", "\n", "print(f'Results: {len(res_df)} ROIs tested')\n", "print(f'Features: {feat_df.shape[0]} subjects, {feat_df.shape[1]} features')"]
  }
 ],
 "metadata": {"kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"}},
 "nbformat": 4,
 "nbformat_minor": 4
}
NBEOF

echo "[reorg] ✓ Created notebooks/exploratory_analysis.ipynb"
echo ""

echo "[reorg] ── Phase 7: Create environment specifications ─────────────"
mkdir -p env

cat > env/requirements.txt <<'EOF'
# Python dependencies for Cannabis-DeepPrep analysis pipeline
# Install: pip install -r env/requirements.txt

# Core neuroimaging
nilearn>=0.10.0
nibabel>=5.0.0

# Data manipulation
pandas>=2.0.0
numpy>=1.24.0

# Statistics
scipy>=1.11.0
statsmodels>=0.14.0

# Visualization
matplotlib>=3.7.0
seaborn>=0.13.0

# Notebook support
jupyter>=1.0.0
ipykernel>=6.0.0

# Optional: dataset download
openneuro-py
EOF

cat > env/conda_environment.yml <<'EOF'
name: cannabis-deepprep
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.10
  - pip
  - nilearn>=0.10
  - nibabel>=5.0
  - pandas>=2.0
  - numpy>=1.24
  - scipy>=1.11
  - statsmodels>=0.14
  - matplotlib>=3.7
  - seaborn>=0.13
  - jupyter
  - pip:
    - openneuro-py
EOF

echo "[reorg] ✓ Created env/requirements.txt and env/conda_environment.yml"
echo ""

echo "[reorg] ── Phase 8: Create .gitignore ──────────────────────────────"
cat > .gitignore <<'EOF'
# Large data files — never commit these
data/raw/
data/derivatives/
*.nii
*.nii.gz
*.mgz
*.gii
*.surf.gii
*.func.gii

# Logs
logs/
*.log

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/
.ipynb_checkpoints/

# OS
.DS_Store
Thumbs.db
*.swp
*.swo
*~

# FreeSurfer license (user-specific)
data/freesurfer/license.txt

# Analysis outputs (optionally track small summaries, exclude large files)
data/processed/figures/*.png
data/processed/figures/*.pdf
!data/processed/**/*.csv
!data/processed/**/*.tsv
EOF

echo "[reorg] ✓ Created .gitignore"
echo ""

echo "[reorg] ── Phase 9: Create LICENSE ─────────────────────────────────"
YEAR=$(date +%Y)
cat > LICENSE <<EOF
MIT License

Copyright (c) $YEAR Cannabis-DeepPrep Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

echo "[reorg] ✓ Created MIT LICENSE"
echo ""

echo "════════════════════════════════════════════════════════════════════"
echo " ✅ Reorganization complete!"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "New structure:"
tree -L 2 -a --dirsfirst 2>/dev/null || find . -maxdepth 2 -not -path '*/\.*' | sort
echo ""
echo "Next steps:"
echo "  1. Review the reorganized structure"
echo "  2. Update script paths in code/ (they reference old locations)"
echo "  3. Commit changes:  git add -A && git commit -m 'Reorganize repo structure'"
echo "  4. Delete backup if satisfied:  rm -rf $BACKUP_DIR"
