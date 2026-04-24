#!/bin/bash -ue
mkdir transforms

talairach_avi --i /output/Recon/sub-101/mri/orig_nu.mgz --xfm /output/Recon/sub-101/mri/transforms/talairach.auto.xfm
cp /output/Recon/sub-101/mri/transforms/talairach.auto.xfm /output/Recon/sub-101/mri/transforms/talairach.xfm

lta_convert --src /output/Recon/sub-101/mri/orig.mgz --trg /opt/freesurfer/average/mni305.cor.mgz     --inxfm /output/Recon/sub-101/mri/transforms/talairach.xfm --outlta /output/Recon/sub-101/mri/transforms/talairach.xfm.lta     --subject fsaverage --ltavox2vox

cp /output/Recon/sub-101/mri/transforms/talairach.xfm.lta /output/Recon/sub-101/mri/transforms/talairach_with_skull.lta
cp /output/Recon/sub-101/mri/transforms/talairach.xfm.lta /output/Recon/sub-101/mri/transforms/talairach.lta

mri_add_xform_to_header -c /output/Recon/sub-101/mri/transforms/talairach.xfm /output/Recon/sub-101/mri/orig_nu.mgz /output/Recon/sub-101/mri/nu.mgz
