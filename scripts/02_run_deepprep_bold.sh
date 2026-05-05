#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# 02_run_deepprep_bold.sh — fMRI (BOLD) preprocessing — PLACEHOLDER
#
# Status: Not implemented in the current pilot.
#
# The ds000174 dataset used by this project contains only T1-weighted
# structural MRI. Functional connectivity / task-based fMRI analysis
# is future work and would require:
#
#   1. A BIDS dataset with `func/*_bold.nii.gz` files (e.g., ds003702)
#   2. Removing the `--anat_only` flag from the DeepPrep invocation
#   3. Adding fMRI-specific QC and motion-scrubbing parameters
#
# See the DeepPrep documentation:
#   https://deepprep.readthedocs.io/en/latest/
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

cat <<'EOF'
╔══════════════════════════════════════════════════════════════════╗
║  fMRI (BOLD) preprocessing is not implemented in this pilot.    ║
║                                                                  ║
║  The pilot study used ds000174, which contains only structural  ║
║  T1-weighted MRI. To extend to functional analysis:             ║
║                                                                  ║
║    1. Choose a BIDS dataset with BOLD data (e.g., ds003702)     ║
║    2. Edit this script: drop --anat_only from the docker run    ║
║    3. Add fMRI-specific QC and analysis steps                   ║
║                                                                  ║
║  See README.md → "Future Work" for details.                     ║
╚══════════════════════════════════════════════════════════════════╝
EOF

exit 0
