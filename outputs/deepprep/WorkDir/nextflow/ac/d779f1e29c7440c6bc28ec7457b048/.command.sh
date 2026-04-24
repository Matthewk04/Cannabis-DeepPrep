#!/bin/bash -ue
qc_anat_vol_surface.py     --subject_id sub-101     --subjects_dir /output/Recon     --qc_result_path /output/QC     --affine_mat /opt/DeepPrep/deepprep/nextflow/bin/qc_tool/affine.mat     --scene_file /opt/DeepPrep/deepprep/nextflow/bin/qc_tool/Vol_Surface.scene     --svg_outpath /output/QC/sub-101/figures/sub-101_desc-volsurf_T1w.svg     --freesurfer_home /opt/freesurfer
