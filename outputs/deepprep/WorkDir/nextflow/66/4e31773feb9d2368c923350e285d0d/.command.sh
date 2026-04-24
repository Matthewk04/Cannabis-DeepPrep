#!/bin/bash -ue
qc_create_report.py     --reports_utils_path /opt/DeepPrep/deepprep/nextflow/bin/reports     --subject_id sub-101     --bids_dir /input     --subjects_dir /output/Recon     --qc_result_path /output/QC
