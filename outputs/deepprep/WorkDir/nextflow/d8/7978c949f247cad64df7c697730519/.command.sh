#!/bin/bash -ue
gpu_schedule_run.py auto 5000 executor /opt/DeepPrep/deepprep/SUGAR/predict.py --sd /output/Recon --sid sub-101 --fsd /opt/freesurfer     --hemi rh --model_path /opt/model/SUGAR/model_files --device auto
