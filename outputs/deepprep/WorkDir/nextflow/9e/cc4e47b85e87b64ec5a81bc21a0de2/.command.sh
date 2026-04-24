#!/bin/bash -ue
mris_smooth -n 3 -nw  /output/Recon/sub-101/surf/lh.white.preaparc /output/Recon/sub-101/surf/lh.smoothwm
mris_inflate /output/Recon/sub-101/surf/lh.smoothwm /output/Recon/sub-101/surf/lh.inflated
