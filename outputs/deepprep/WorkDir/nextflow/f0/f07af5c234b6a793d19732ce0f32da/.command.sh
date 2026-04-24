#!/bin/bash -ue
df -h

gpu_schedule_lock.py executor

input_bids_validator.py     --bids_dir /input     --exec_env docker     --participant_label 101     --skip_bids_validation true

deepprep_init.py     --freesurfer_home /opt/freesurfer     --bids_dir /input     --output_dir /output     --subjects_dir /output/Recon     --bold_spaces fsaverage6     --bold_only False
