#!/bin/bash -ue
mris_place_surface --adgws-in /output/Recon/sub-101/surf/autodet.gw.stats.lh.dat --wm /output/Recon/sub-101/mri/wm.mgz     --nthreads 4 --invol /output/Recon/sub-101/mri/brain.finalsurfs.mgz --lh --i /output/Recon/sub-101/surf/lh.orig     --o /output/Recon/sub-101/surf/lh.white.preaparc     --white --seg /output/Recon/sub-101/mri/aseg.presurf.mgz --nsmooth 5

mris_place_surface --curv-map /output/Recon/sub-101/surf/lh.white.preaparc 2 10 /output/Recon/sub-101/surf/lh.curv
mris_place_surface --area-map /output/Recon/sub-101/surf/lh.white.preaparc /output/Recon/sub-101/surf/lh.area

cp /output/Recon/sub-101/surf/lh.white.preaparc /output/Recon/sub-101/surf/lh.white
