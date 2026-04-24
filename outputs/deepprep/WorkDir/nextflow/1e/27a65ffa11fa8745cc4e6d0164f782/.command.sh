#!/bin/bash -ue
mris_ca_label -SDIR /output/Recon -l /output/Recon/sub-101/label/rh.cortex.label -aseg /output/Recon/sub-101/mri/aseg.presurf.mgz -seed 1234 sub-101 rh /output/Recon/sub-101/surf/rh.sphere.reg     /opt/freesurfer/average/rh.curvature.buckner40.filled.desikan_killiany.2010-03-25.gcs     /output/Recon/sub-101/label/rh.aparc.annot
