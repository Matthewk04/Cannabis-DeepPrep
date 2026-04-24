Node: sub-101_T1w_Reports_run_node
==================================


 Hierarchy : sub-101_T1w_Reports_run_node
 Exec ID : sub-101_T1w_Reports_run_node


Original Inputs
---------------


* max_scale : 3.0
* t1w_list : ['/input/sub-101/ses-BL/anat/sub-101_ses-BL_T1w.nii.gz']


Execution Inputs
----------------


* max_scale : 3.0
* t1w_list : ['/input/sub-101/ses-BL/anat/sub-101_ses-BL_T1w.nii.gz']


Execution Outputs
-----------------


* out_report : /output/WorkDir/anat_create_summary/sub-101/sub-101_T1w_Reports_run_node/report.html
* t1w_valid_list : /input/sub-101/ses-BL/anat/sub-101_ses-BL_T1w.nii.gz
* target_shape : (256, 182, 256)
* target_zooms : (0.8800000548362732, 1.2000001668930054, 0.8800000548362732)


Runtime info
------------


* duration : 0.390143
* hostname : 8eb296a60dbd
* prev_wd : /output/WorkDir/nextflow/9b/a037b1aa2ba80a8f8550085b150a79
* working_dir : /output/WorkDir/anat_create_summary/sub-101/sub-101_T1w_Reports_run_node


Environment
~~~~~~~~~~~


* ANTSPATH : /opt/ANTs/bin
* ANTS_RANDOM_SEED : 14193
* CAPSULE_CACHE_DIR : /home/deepprep/.nextflow/capsule
* CPATH : /opt/conda/envs/deepprep/include:
* CUDA_VERSION : 11.8.0
* DEBIAN_FRONTEND : noninteractive
* DEEPPREP_VERSION : 25.1.0
* FIX_VERTEX_AREA : 
* FMRI_ANALYSIS_DIR : /opt/freesurfer/fsfast
* FREESURFER : /opt/freesurfer
* FREESURFER_HOME : /opt/freesurfer
* FSFAST_HOME : /opt/freesurfer/fsfast
* FSF_OUTPUT_FORMAT : nii.gz
* FSLCONVERT : /usr/bin/convert
* FSLDIR : /opt/fsl
* FSLDISPLAY : /usr/bin/display
* FSLGECUDAQ : cuda.q
* FSLLOCKDIR : 
* FSLMACHINELIST : 
* FSLMULTIFILEQUIT : TRUE
* FSLOUTPUTTYPE : NIFTI_GZ
* FSLREMOTECALL : 
* FSL_BIN : /opt/fsl/bin
* FSL_DIR : /opt/fsl
* FS_LICENSE : /fs_license.txt
* FS_OVERRIDE : 0
* FUNCTIONALS_DIR : /opt/freesurfer/sessions
* GDCM_RESOURCES_PATH : /opt/conda/envs/deepprep/lib/python3.10/site-packages/_gdcm/XML
* HOME : /home/deepprep
* HOSTNAME : 8eb296a60dbd
* JAVA_CMD : /usr/lib/jvm/java-11-openjdk-amd64/bin/java
* JAVA_HOME : /usr/lib/jvm/java-11-openjdk-amd64
* LANG : C.UTF-8
* LC_ALL : C.UTF-8
* LD_LIBRARY_PATH : /usr/lib/jvm/java-11-openjdk-amd64/lib/server:/usr/lib/jvm/java-11-openjdk-amd64/lib:/usr/lib/jvm/java-11-openjdk-amd64/../lib:/opt/conda/envs/deepprep/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/lib/jvm/java-11-openjdk-amd64/lib:/usr/lib/jvm/java-11-openjdk-amd64/lib/server
* LOCAL_DIR : /opt/freesurfer/local
* MAMBA_ROOT_PREFIX : /opt/conda
* MINC_BIN_DIR : /opt/freesurfer/mni/bin
* MINC_LIB_DIR : /opt/freesurfer/mni/lib
* MNI_DATAPATH : /opt/freesurfer/mni/data
* MNI_DIR : /opt/freesurfer/mni
* MNI_PERL5LIB : /opt/freesurfer/mni/share/perl5
* NCCL_VERSION : 2.15.5-1
* NVARCH : x86_64
* NVIDIA_CTK_LIBCUDA_DIR : /usr/lib/x86_64-linux-gnu
* NVIDIA_DRIVER_CAPABILITIES : compute,utility
* NVIDIA_PRODUCT_NAME : CUDA
* NVIDIA_REQUIRE_CUDA : cuda>=11.8 brand=tesla,driver>=470,driver<471 brand=unknown,driver>=470,driver<471 brand=nvidia,driver>=470,driver<471 brand=nvidiartx,driver>=470,driver<471 brand=geforce,driver>=470,driver<471 brand=geforcertx,driver>=470,driver<471 brand=quadro,driver>=470,driver<471 brand=quadrortx,driver>=470,driver<471 brand=titan,driver>=470,driver<471 brand=titanrtx,driver>=470,driver<471
* NVIDIA_VISIBLE_DEVICES : void
* NV_CUDA_COMPAT_PACKAGE : cuda-compat-11-8
* NV_CUDA_CUDART_VERSION : 11.8.89-1
* NV_CUDA_LIB_VERSION : 11.8.0-1
* NV_CUDNN_PACKAGE : libcudnn8=8.9.6.50-1+cuda11.8
* NV_CUDNN_PACKAGE_NAME : libcudnn8
* NV_CUDNN_VERSION : 8.9.6.50
* NV_LIBCUBLAS_PACKAGE : libcublas-11-8=11.11.3.6-1
* NV_LIBCUBLAS_PACKAGE_NAME : libcublas-11-8
* NV_LIBCUBLAS_VERSION : 11.11.3.6-1
* NV_LIBCUSPARSE_VERSION : 11.7.5.86-1
* NV_LIBNCCL_PACKAGE : libnccl2=2.15.5-1+cuda11.8
* NV_LIBNCCL_PACKAGE_NAME : libnccl2
* NV_LIBNCCL_PACKAGE_VERSION : 2.15.5-1
* NV_LIBNPP_PACKAGE : libnpp-11-8=11.8.0.86-1
* NV_LIBNPP_VERSION : 11.8.0.86-1
* NV_NVTX_VERSION : 11.8.86-1
* NXF_CLI : /opt/nextflow/bin/nextflow run /opt/DeepPrep/deepprep/nextflow/deepprep.nf -c /output/WorkDir/nextflow/run.config -w /output/WorkDir/nextflow -with-report /output/QC/report.html -with-timeline /output/QC/timeline.html --bids_dir /input --output_dir /output --anat_only --fs_license_file /fs_license.txt --cpus 10 --memory 20 --skip_bids_validation --participant_label 101
* NXF_HOME : /home/deepprep/.nextflow
* NXF_OFFLINE : true
* NXF_ORG : nextflow-io
* NXF_PACK : one
* NXF_TASK_WORKDIR : /output/WorkDir/nextflow/9b/a037b1aa2ba80a8f8550085b150a79
* OLDPWD : /home/deepprep
* OS : Linux
* PATH : /opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/fsl/bin:/opt/freesurfer/mni/bin:/opt/conda/envs/deepprep/bin:/opt/nextflow/bin:/opt/abin:/opt/ANTs/bin:/opt/workbench/bin_linux64:/opt/fsl/bin:/opt/freesurfer/tktools:/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/mni/bin:/opt/node-v20.18.1-linux-x64/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/DeepPrep/deepprep/nextflow/bin
* PERL5LIB : /opt/freesurfer/mni/share/perl5
* PWD : /output/WorkDir/nextflow/9b/a037b1aa2ba80a8f8550085b150a79
* PYTHONNOUSERSITE : 1
* SHLVL : 3
* SUBJECTS_DIR : /opt/freesurfer/subjects
* TZ : Etc/UTC
* UV_USE_IO_URING : 0
* _ : /opt/DeepPrep/deepprep/nextflow/bin/qc_create_summary.py

