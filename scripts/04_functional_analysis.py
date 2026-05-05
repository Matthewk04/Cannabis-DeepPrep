#!/usr/bin/env python3
"""
04_functional_analysis.py — Functional connectivity analysis — PLACEHOLDER

Status: Not implemented in the current pilot.

The ds000174 dataset contains only structural MRI (T1w), so this script is
a stub. To implement functional analysis, you would:

    1. Use a BIDS dataset with BOLD data (e.g., ds003702)
    2. Run scripts/02_run_deepprep_bold.sh (also a placeholder; see that
       file for required edits)
    3. Implement here:
        - Load preprocessed BOLD data (typically in MNI152 space)
        - Define seed regions or parcellation (e.g., Schaefer 400)
        - Compute functional connectivity matrices
        - Group comparison via Welch's t-test + FDR correction
        - Effect-size estimation (Cohen's d)

Library suggestions:
    - nilearn  — high-level connectivity / GLM
    - nibabel  — low-level NIfTI I/O
    - scipy.stats / statsmodels — group statistics

See the README "Future Work" section for the planned design.
"""
import sys


def main() -> int:
    print(__doc__.strip())
    print("\n[exit] Functional analysis not implemented — exiting.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
