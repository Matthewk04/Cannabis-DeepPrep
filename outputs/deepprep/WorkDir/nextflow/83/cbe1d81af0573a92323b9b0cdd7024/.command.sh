#!/bin/bash -ue
mri_mask /output/Recon/sub-101/mri/nu.mgz /output/Recon/sub-101/mri/mask.mgz /output/Recon/sub-101/mri/norm.mgz
cp /output/Recon/sub-101/mri/norm.mgz /output/Recon/sub-101/mri/brainmask.mgz
