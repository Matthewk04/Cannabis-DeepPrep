#!/bin/bash -ue
python3 /opt/DeepPrep/deepprep/FastCSR/levelset2surf.py     --fastcsr_subjects_dir /output/Recon     --subj sub-101     --hemi rh     --suffix orig

cp /output/Recon/sub-101/surf/rh.orig /output/Recon/sub-101/surf/rh.orig.premesh
