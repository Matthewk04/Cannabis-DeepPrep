#!/bin/bash -ue
mris_place_surface --adgws-in /output/Recon/sub-101/surf/autodet.gw.stats.lh.dat --seg /output/Recon/sub-101/mri/aseg.presurf.mgz --nthreads 4 --wm /output/Recon/sub-101/mri/wm.mgz     --invol /output/Recon/sub-101/mri/brain.finalsurfs.mgz --lh --i /output/Recon/sub-101/surf/lh.white --o /output/Recon/sub-101/surf/lh.pial.T1     --pial --nsmooth 0 --rip-label /output/Recon/sub-101/label/lh.cortex+hipamyg.label --pin-medial-wall /output/Recon/sub-101/label/lh.cortex.label --aparc /output/Recon/sub-101/label/lh.aparc.annot --repulse-surf /output/Recon/sub-101/surf/lh.white --white-surf /output/Recon/sub-101/surf/lh.white
cp -f /output/Recon/sub-101/surf/lh.pial.T1 /output/Recon/sub-101/surf/lh.pial

mris_place_surface --curv-map /output/Recon/sub-101/surf/lh.pial.T1 2 10 /output/Recon/sub-101/surf/lh.curv.pial
mris_place_surface --area-map /output/Recon/sub-101/surf/lh.pial.T1 /output/Recon/sub-101/surf/lh.area.pial
mris_place_surface --thickness /output/Recon/sub-101/surf/lh.white /output/Recon/sub-101/surf/lh.pial.T1 20 5 /output/Recon/sub-101/surf/lh.thickness

mris_calc -o /output/Recon/sub-101/surf/lh.area.mid /output/Recon/sub-101/surf/lh.area add /output/Recon/sub-101/surf/lh.area.pial
mris_calc -o /output/Recon/sub-101/surf/lh.area.mid /output/Recon/sub-101/surf/lh.area.mid div 2
SUBJECTS_DIR=/output/Recon mris_convert --volume sub-101 lh /output/Recon/sub-101/surf/lh.volume
