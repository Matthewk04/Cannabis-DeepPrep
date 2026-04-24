#!/bin/bash -ue
mri_cc -aseg aseg.auto_noCCseg.mgz -norm norm.mgz -o aseg.auto.mgz -lta cc_up.lta -sdir /output/Recon sub-101

python3 /opt/DeepPrep/deepprep/FastSurfer/recon_surf/paint_cc_into_pred.py -in_cc /output/Recon/sub-101/mri/aseg.auto.mgz -in_pred /output/Recon/sub-101/mri/aparc.DKTatlas+aseg.deep.mgz -out /output/Recon/sub-101/mri/aparc.DKTatlas+aseg.deep.withCC.mgz
