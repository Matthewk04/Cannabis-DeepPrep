#!/usr/bin/env bash
# =============================================================================
# 02_run_deepprep_bold.sh
# DeepPrep 25.1.0 — Full fMRI pipeline (Track B)
# Platform: Ubuntu 22.04 (Jammy) on FABRIC testbed
#
# ⚠  PREREQUISITE: ds000174 has NO BOLD data.
#    Point BIDS_DIR at an fMRI-capable dataset (e.g. ds003702).
#    See README.md → "Track B / fMRI Dataset Alternatives"
#
# DeepPrep 25.1.0 fMRI steps:
#   1. T1w anat preprocessing (FastSurfer + FastCSR + SUGAR + SynthMorph)
#   2. Motion correction (MCFLIRT, FSL)
#   3. Slice-timing correction (3dTshift, AFNI) — when metadata present
#   4. Susceptibility distortion correction (SDCFlows) — when fieldmap present
#   5. BOLD→T1w co-registration (FreeSurfer BBR)
#   6. Spatial normalisation → MNI152NLin6Asym (vol) + fsaverage6 (surf)
#   7. Confound generation (motion params, WM, CSF, global signal, FD)
#
# Usage:
#   bash scripts/02_run_deepprep_bold.sh              # all subjects, task=rest
#   bash scripts/02_run_deepprep_bold.sh sub-01 rest  # one subject, one task
# =============================================================================
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
DEEPPREP_IMAGE="pbfslab/deepprep:25.1.0"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ⚡ EDIT: point this at your fMRI BIDS dataset (NOT ds000174)
BIDS_DIR="$PROJ_DIR/data/bids/fmri_cannabis_dataset"

OUTPUT_DIR="$PROJ_DIR/outputs/deepprep"
FS_LICENSE="$PROJ_DIR/data/freesurfer/license.txt"

BOLD_TASK="${2:-rest}"    # matches task label in BIDS filenames
CPUS=10
MEMORY_GB=20

# ── Input validation ──────────────────────────────────────────────────────────
if [ ! -d "$BIDS_DIR" ]; then
  echo "❌ BIDS directory not found: $BIDS_DIR"
  echo ""
  echo "   ds000174 contains no BOLD fMRI. To run Track B, download an"
  echo "   fMRI-capable dataset, e.g.:"
  echo ""
  echo "   aws s3 sync --no-sign-request \\"
  echo "     s3://openneuro.org/ds003702 \\"
  echo "     $PROJ_DIR/data/bids/fmri_cannabis_dataset/"
  echo ""
  echo "   Then update BIDS_DIR in this script."
  exit 1
fi

if [ ! -f "$FS_LICENSE" ]; then
  echo "❌ FreeSurfer license not found: $FS_LICENSE"
  exit 1
fi

BOLD_COUNT=$(find "$BIDS_DIR" -name "*task-${BOLD_TASK}_bold.nii.gz" 2>/dev/null | wc -l)
if [ "$BOLD_COUNT" -eq 0 ]; then
  echo "❌ No BOLD files found for task '${BOLD_TASK}' in $BIDS_DIR"
  echo "   Tasks available:"
  find "$BIDS_DIR" -name "*_task-*_bold.nii.gz" 2>/dev/null \
    | grep -oP '(?<=task-)[a-zA-Z0-9]+' | sort -u \
    || echo "   (none)"
  exit 1
fi
echo "[deepprep] Found ${BOLD_COUNT} BOLD run(s) for task: ${BOLD_TASK}"

mkdir -p "$OUTPUT_DIR" "$PROJ_DIR/logs"

# ── GPU detection — Ubuntu 22.04 / NVIDIA Container Toolkit ──────────────────
GPU_FLAG=""
DEVICE_FLAG=""

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
  if docker info 2>/dev/null | grep -qi "nvidia\|Runtimes.*nvidia"; then
    GPU_FLAG="--gpus all"
    echo "[deepprep] ✓ GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader \
      | sed 's/^/             /'
  else
    echo "[deepprep] ⚠  NVIDIA driver present but Docker nvidia runtime not configured."
    echo "            Run: sudo nvidia-ctk runtime configure --runtime=docker"
    echo "                 sudo systemctl restart docker"
    DEVICE_FLAG="--device cpu"
  fi
else
  echo "[deepprep] ⚠  No GPU detected — CPU fallback (slower but supported)."
  DEVICE_FLAG="--device cpu"
fi

# ── Subject filter ────────────────────────────────────────────────────────────
PARTICIPANT_FLAG=""
if [ -n "${1:-}" ]; then
  SUB_LABEL="${1#sub-}"
  PARTICIPANT_FLAG="--participant_label ${SUB_LABEL}"
  echo "[deepprep] Single-subject mode: sub-${SUB_LABEL}"
fi

# ── Run ───────────────────────────────────────────────────────────────────────
LOG_FILE="$PROJ_DIR/logs/deepprep_bold_$(date +%Y%m%d_%H%M%S).log"
echo ""
echo "============================================================"
echo " DeepPrep 25.1.0 — Full fMRI Pipeline"
echo "   Task:   $BOLD_TASK"
echo "   Image:  $DEEPPREP_IMAGE"
echo "   Input:  $BIDS_DIR"
echo "   Output: $OUTPUT_DIR"
echo "   CPUs:   $CPUS    Memory: ${MEMORY_GB} GB"
echo "   Log:    $LOG_FILE"
echo "============================================================"
echo ""

# --shm-size 8g : DeepPrep 25.1.0 uses PyTorch ops that require substantial
#                 shared memory. Ubuntu 22.04 defaults /dev/shm to 64 MB
#                 (half of RAM) which is far too small; crashes are silent.
# --ulimit nofile: Nextflow opens many file descriptors in parallel runs.
# Output spaces: MNI152NLin6Asym vol (standard for FSL/SPM second-level)
#                fsaverage6 surf (matches HCP convention used in DeepPrep)
docker run --rm \
  ${GPU_FLAG:-} \
  --shm-size 8g \
  --ulimit nofile=65536:65536 \
  -v "${BIDS_DIR}:/input:ro" \
  -v "${OUTPUT_DIR}:/output" \
  -v "${FS_LICENSE}:/fs_license.txt:ro" \
  "$DEEPPREP_IMAGE" \
  /input \
  /output \
  participant \
  --bold_task_type "${BOLD_TASK}" \
  --fs_license_file /fs_license.txt \
  --bold_sdc \
  --bold_confounds \
  --bold_volume_space MNI152NLin6Asym \
  --bold_volume_res 02 \
  --bold_surface_spaces 'fsnative fsaverage6' \
  --cpus "${CPUS}" \
  --memory "${MEMORY_GB}" \
  --skip_bids_validation \
  ${DEVICE_FLAG:-} \
  ${PARTICIPANT_FLAG:-} \
  2>&1 | tee "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ DeepPrep 25.1.0 fMRI preprocessing complete."
  echo ""
  echo "   Key outputs per subject (under $OUTPUT_DIR/sub-XX/):"
  echo "   ├── anat/  → T1w derivatives, brain mask, segmentation, surfaces"
  echo "   └── func/"
  echo "       ├── *_space-MNI152NLin6Asym_res-02_desc-preproc_bold.nii.gz"
  echo "       ├── *_space-fsaverage6_hemi-L_bold.func.gii"
  echo "       ├── *_space-fsaverage6_hemi-R_bold.func.gii"
  echo "       └── *_desc-confounds_timeseries.tsv"
  echo "              (motion params, WM, CSF, global signal, FD, tSNR)"
  echo ""
  echo "   HTML QC reports: $OUTPUT_DIR/sub-XX/sub-XX*.html"
  echo ""
  echo "   Next: python3 scripts/04_functional_analysis.py"
else
  echo "❌ DeepPrep exited with code $EXIT_CODE"
  echo "   Check log: $LOG_FILE"
  echo ""
  echo "   Common Ubuntu 22.04 issues:"
  echo "   • 'RuntimeError: CUDA' → GPU runtime not configured"
  echo "     Fix: sudo nvidia-ctk runtime configure --runtime=docker"
  echo "          sudo systemctl restart docker"
  echo "   • 'no space left on /dev/shm' → already handled by --shm-size 8g"
  echo "   • 'Nextflow error' → check log tail for the failed process"
  echo "   • 'permission denied' → sudo usermod -aG docker \$USER && newgrp docker"
  exit $EXIT_CODE
fi
