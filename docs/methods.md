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
