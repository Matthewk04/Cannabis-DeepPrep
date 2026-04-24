#!/bin/bash -ue
SUBJECTS_DIR=/output/Recon mri_surf2volseg --o /output/Recon/sub-101/mri/aseg.mgz --i /output/Recon/sub-101/mri/aseg.presurf.hypos.mgz     --fix-presurf-with-ribbon /output/Recon/sub-101/mri/ribbon.mgz     --nthreads 8     --lh-cortex-mask /output/Recon/sub-101/label/lh.cortex.label --lh-white /output/Recon/sub-101/surf/lh.white --lh-pial /output/Recon/sub-101/surf/lh.pial     --rh-cortex-mask /output/Recon/sub-101/label/rh.cortex.label --rh-white /output/Recon/sub-101/surf/rh.white --rh-pial /output/Recon/sub-101/surf/rh.pial

SUBJECTS_DIR=/output/Recon mri_brainvol_stats sub-101
