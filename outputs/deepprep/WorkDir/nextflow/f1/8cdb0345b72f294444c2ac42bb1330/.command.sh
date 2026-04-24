#!/bin/bash -ue
mris_ca_label -SDIR /output/Recon -l /output/Recon/sub-101/label/lh.cortex.label -aseg /output/Recon/sub-101/mri/aseg.presurf.mgz -seed 1234 sub-101 lh /output/Recon/sub-101/surf/lh.sphere.reg     /opt/freesurfer/average/lh.curvature.buckner40.filled.desikan_killiany.2010-03-25.gcs     /output/Recon/sub-101/label/lh.aparc.annot
