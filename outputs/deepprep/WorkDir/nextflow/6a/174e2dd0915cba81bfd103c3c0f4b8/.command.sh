#!/bin/bash -ue
SUBJECTS_DIR=/output/Recon mris_curvature_stats -m --writeCurvatureFiles -G -o "/output/Recon/sub-101/stats/rh.curv.stats" -F smoothwm sub-101 rh curv sulc
