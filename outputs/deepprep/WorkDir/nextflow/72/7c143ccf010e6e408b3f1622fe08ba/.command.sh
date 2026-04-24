#!/bin/bash -ue
python3 /opt/DeepPrep/deepprep/FastSurfer/recon_surf/N4_bias_correct.py     --in /output/Recon/sub-101/mri/orig.mgz     --out /output/Recon/sub-101/mri/orig_nu.mgz     --mask /output/Recon/sub-101/mri/mask.mgz     --threads 8
