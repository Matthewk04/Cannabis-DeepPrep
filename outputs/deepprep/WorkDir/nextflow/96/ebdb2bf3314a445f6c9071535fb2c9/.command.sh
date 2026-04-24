#!/bin/bash -ue
mris_place_surface --adgws-in /output/Recon/sub-101/surf/autodet.gw.stats.rh.dat --seg /output/Recon/sub-101/mri/aseg.presurf.mgz --nthreads 4 --wm /output/Recon/sub-101/mri/wm.mgz     --invol /output/Recon/sub-101/mri/brain.finalsurfs.mgz --rh --i /output/Recon/sub-101/surf/rh.white --o /output/Recon/sub-101/surf/rh.pial.T1     --pial --nsmooth 0 --rip-label /output/Recon/sub-101/label/rh.cortex+hipamyg.label --pin-medial-wall /output/Recon/sub-101/label/rh.cortex.label --aparc /output/Recon/sub-101/label/rh.aparc.annot --repulse-surf /output/Recon/sub-101/surf/rh.white --white-surf /output/Recon/sub-101/surf/rh.white
cp -f /output/Recon/sub-101/surf/rh.pial.T1 /output/Recon/sub-101/surf/rh.pial

mris_place_surface --curv-map /output/Recon/sub-101/surf/rh.pial.T1 2 10 /output/Recon/sub-101/surf/rh.curv.pial
mris_place_surface --area-map /output/Recon/sub-101/surf/rh.pial.T1 /output/Recon/sub-101/surf/rh.area.pial
mris_place_surface --thickness /output/Recon/sub-101/surf/rh.white /output/Recon/sub-101/surf/rh.pial.T1 20 5 /output/Recon/sub-101/surf/rh.thickness

mris_calc -o /output/Recon/sub-101/surf/rh.area.mid /output/Recon/sub-101/surf/rh.area add /output/Recon/sub-101/surf/rh.area.pial
mris_calc -o /output/Recon/sub-101/surf/rh.area.mid /output/Recon/sub-101/surf/rh.area.mid div 2
SUBJECTS_DIR=/output/Recon mris_convert --volume sub-101 rh /output/Recon/sub-101/surf/rh.volume
