

#---------------------------------
# New invocation of recon-all Fri Apr 24 02:32:10 UTC 2026 
#--------------------------------------------
#@# MotionCor Fri Apr 24 02:32:11 UTC 2026

 cp /output/Recon/sub-101/mri/orig/001.mgz /output/Recon/sub-101/mri/rawavg.mgz 


 mri_convert /output/Recon/sub-101/mri/rawavg.mgz /output/Recon/sub-101/mri/orig.mgz --conform 


 mri_add_xform_to_header -c /output/Recon/sub-101/mri/transforms/talairach.xfm /output/Recon/sub-101/mri/orig.mgz /output/Recon/sub-101/mri/orig.mgz 



#---------------------------------
# New invocation of recon-all Fri Apr 24 02:34:40 UTC 2026 
#--------------------------------------
#@# Merge ASeg Fri Apr 24 02:34:40 UTC 2026

 cp aseg.auto.mgz aseg.presurf.mgz 

#--------------------------------------------
#@# Intensity Normalization2 Fri Apr 24 02:34:40 UTC 2026

 mri_normalize -seed 1234 -mprage -aseg aseg.presurf.mgz -mask brainmask.mgz norm.mgz brain.mgz 

#--------------------------------------------
#@# Mask BFS Fri Apr 24 02:36:56 UTC 2026

 mri_mask -T 5 brain.mgz brainmask.mgz brain.finalsurfs.mgz 

#--------------------------------------------
#@# WM Segmentation Fri Apr 24 02:36:57 UTC 2026

 AntsDenoiseImageFs -i brain.mgz -o antsdn.brain.mgz 


 mri_segment -wsizemm 13 -mprage antsdn.brain.mgz wm.seg.mgz 


 mri_edit_wm_with_aseg -keep-in wm.seg.mgz brain.mgz aseg.presurf.mgz wm.asegedit.mgz 


 mri_pretess wm.asegedit.mgz wm norm.mgz wm.mgz 

#--------------------------------------------
#@# Fill Fri Apr 24 02:38:53 UTC 2026

 mri_fill -a ../scripts/ponscc.cut.log -xform transforms/talairach.lta -segmentation aseg.presurf.mgz -ctab /opt/freesurfer/SubCorticalMassLUT.txt wm.mgz filled.mgz 

 cp filled.mgz filled.auto.mgz
