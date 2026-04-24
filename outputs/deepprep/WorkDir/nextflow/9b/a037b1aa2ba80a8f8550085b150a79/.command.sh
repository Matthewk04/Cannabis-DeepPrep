#!/bin/bash -ue
qc_create_summary.py     --bids_dir /input     --subjects_dir /output/Recon     --subject_id sub-101     --template_space "NONE"     --qc_result_path /output/QC     --deepprep_version 25.1.0     --nextflow_log /output/WorkDir/nextflow/.nextflow.log     --workdir /output/WorkDir/anat_create_summary
