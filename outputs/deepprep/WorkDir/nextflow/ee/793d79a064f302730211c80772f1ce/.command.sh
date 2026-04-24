#!/bin/bash -ue
recon-all -sd /output/Recon -subject sub-101     -asegmerge -normalization2 -maskbfs -segmentation -fill     -threads 8 -itkthreads 8 -no-isrunning
