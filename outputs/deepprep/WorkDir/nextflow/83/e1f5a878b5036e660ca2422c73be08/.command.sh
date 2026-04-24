#!/bin/bash -ue
mris_smooth -n 3 -nw  /output/Recon/sub-101/surf/rh.white.preaparc /output/Recon/sub-101/surf/rh.smoothwm
mris_inflate /output/Recon/sub-101/surf/rh.smoothwm /output/Recon/sub-101/surf/rh.inflated
