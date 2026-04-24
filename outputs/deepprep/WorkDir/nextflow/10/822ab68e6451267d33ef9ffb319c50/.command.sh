#!/bin/bash -ue
mris_place_surface --adgws-in /output/Recon/sub-101/surf/autodet.gw.stats.rh.dat --wm /output/Recon/sub-101/mri/wm.mgz     --nthreads 4 --invol /output/Recon/sub-101/mri/brain.finalsurfs.mgz --rh --i /output/Recon/sub-101/surf/rh.orig     --o /output/Recon/sub-101/surf/rh.white.preaparc     --white --seg /output/Recon/sub-101/mri/aseg.presurf.mgz --nsmooth 5

mris_place_surface --curv-map /output/Recon/sub-101/surf/rh.white.preaparc 2 10 /output/Recon/sub-101/surf/rh.curv
mris_place_surface --area-map /output/Recon/sub-101/surf/rh.white.preaparc /output/Recon/sub-101/surf/rh.area

cp /output/Recon/sub-101/surf/rh.white.preaparc /output/Recon/sub-101/surf/rh.white
