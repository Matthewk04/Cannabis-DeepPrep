#!/bin/bash -ue
python3 /opt/DeepPrep/deepprep/FastSurfer/recon_surf/reduce_to_aseg.py     -i /output/Recon/sub-101/mri/aparc.DKTatlas+aseg.deep.mgz     -o /output/Recon/sub-101/mri/aseg.auto_noCCseg.mgz     --outmask /output/Recon/sub-101/mri/mask.mgz     --fixwm
