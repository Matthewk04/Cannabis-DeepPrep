#!/bin/bash -ue
gpu_schedule_run.py auto 3150 executor /opt/DeepPrep/deepprep/FastCSR/fastcsr_model_infer.py     --fastcsr_subjects_dir /output/Recon     --subj sub-101     --hemi rh     --model-path /opt/model/FastCSR
