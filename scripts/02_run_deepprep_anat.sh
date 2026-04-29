#!/usr/bin/env bash
# =============================================================================
# 02_run_deepprep_anat.sh
# DeepPrep 25.1.0 — Multi-session structural preprocessing
#
# ds000174 has TWO sessions per subject:
#   - ses-BL  (baseline)
#   - ses-FU  (follow-up)
#
# DeepPrep will crash if you don't specify which session to process.
# This script processes BOTH sessions separately (default) or one at a time.
#
# Usage:
#   bash scripts/02_run_deepprep_anat.sh --pilot           # all pilot subjects, both sessions
#   bash scripts/02_run_deepprep_anat.sh --pilot BL        # pilot subjects, baseline only
#   bash scripts/02_run_deepprep_anat.sh sub-101 FU        # single subject, follow-up only
#   bash scripts/02_run_deepprep_anat.sh sub-101           # single subject, both sessions
# =============================================================================
set -euo pipefail

DEEPPREP_IMAGE="pbfslab/deepprep:25.1.0"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIDS_DIR="$PROJ_DIR/data/bids/ds000174"
OUTPUT_DIR="$PROJ_DIR/outputs/deepprep"
FS_LICENSE="$PROJ_DIR/data/freesurfer/license.txt"
CPUS=10
MEMORY_GB=20

# ── Input validation ──────────────────────────────────────────────────────────
if [ ! -d "$BIDS_DIR" ]; then
  echo "❌ BIDS dataset not found: $BIDS_DIR"
  echo "   Run: bash scripts/01_download_data.sh"
  exit 1
fi
if [ ! -f "$FS_LICENSE" ]; then
  echo "❌ FreeSurfer license not found: $FS_LICENSE"
  exit 1
fi
mkdir -p "$OUTPUT_DIR" "$PROJ_DIR/logs"

# ── Parse arguments ───────────────────────────────────────────────────────────
MODE=""
PARTICIPANT_FLAG=""
SESSIONS=("BL" "FU")   # default: process both sessions

# Check if second argument specifies a session
if [ "${2:-}" = "BL" ] || [ "${2:-}" = "FU" ]; then
  SESSIONS=("${2}")
  echo "[deepprep] Session filter: ses-${2} only"
fi

if [ "${1:-}" = "--pilot" ]; then
  PILOT_FILE="$PROJ_DIR/outputs/analysis/pilot_subjects.txt"
  if [ ! -f "$PILOT_FILE" ]; then
    echo "❌ pilot_subjects.txt not found."
    echo "   Run first: python3 scripts/03_group_participants.py"
    exit 1
  fi
  PILOT_IDS=$(tr '\n' ' ' < "$PILOT_FILE" | sed 's/[[:space:]]*$//')
  PARTICIPANT_FLAG="--participant_label '${PILOT_IDS}'"
  MODE="pilot"
  echo "[deepprep] Pilot mode: subjects ${PILOT_IDS}"

elif [ -n "${1:-}" ] && [ "${1}" != "--pilot" ]; then
  SUB_LABEL="${1#sub-}"
  PARTICIPANT_FLAG="--participant_label ${SUB_LABEL}"
  MODE="single"
  echo "[deepprep] Single-subject mode: sub-${SUB_LABEL}"

else
  N_SUBS=$(ls -d "$BIDS_DIR"/sub-* 2>/dev/null | wc -l)
  MODE="all"
  echo "[deepprep] Batch mode: all ${N_SUBS} subjects"
fi

# ── GPU detection ─────────────────────────────────────────────────────────────
GPU_FLAG=""
COMPUTE_MODE=""

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
  if docker info 2>/dev/null | grep -qi "nvidia\|Runtimes.*nvidia"; then
    GPU_FLAG="--gpus all"
    COMPUTE_MODE="GPU"
    echo "[deepprep] ✓ GPU detected — using GPU acceleration"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | sed 's/^/             /'
    echo "[deepprep]   Expected runtime: ~9 min/subject on RTX 6000"
  else
    echo "[deepprep] ⚠  GPU hardware found but Docker nvidia runtime not configured"
    echo "[deepprep]   Fix: sudo nvidia-ctk runtime configure --runtime=docker"
    echo "[deepprep]        sudo systemctl restart docker"
    echo "[deepprep]   Falling back to CPU mode"
    COMPUTE_MODE="CPU"
  fi
else
  echo "[deepprep] No GPU detected — using CPU mode"
  echo "[deepprep]   Expected runtime: ~100 min/subject"
  COMPUTE_MODE="CPU"
fi

# ── Process each session separately ───────────────────────────────────────────
echo ""
echo "============================================================"
echo " DeepPrep 25.1.0 — Multi-session structural preprocessing"
echo "   Mode:     $MODE"
echo "   Sessions: ${SESSIONS[*]}"
echo "   Compute:  $COMPUTE_MODE"
echo "   Input:    $BIDS_DIR"
echo "   Output:   $OUTPUT_DIR"
echo "============================================================"

# ── GPU smoke test (if GPU mode) ──────────────────────────────────────────────
if [ "$COMPUTE_MODE" = "GPU" ]; then
  echo ""
  echo "[deepprep] Testing GPU access inside Docker container..."
  if docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi -L 2>/dev/null; then
    echo "[deepprep] ✅ GPU confirmed accessible inside Docker"
  else
    echo "[deepprep] ⚠️  GPU test failed — falling back to CPU"
    GPU_FLAG=""
    COMPUTE_MODE="CPU"
  fi
fi

echo ""

for SESSION in "${SESSIONS[@]}"; do
  SESSION_FLAG="--session_label ${SESSION}"
  LOG_FILE="$PROJ_DIR/logs/deepprep_anat_ses-${SESSION}_$(date +%Y%m%d_%H%M%S).log"

  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo " Processing session: ses-${SESSION}"
  echo " Log: $LOG_FILE"
  echo "────────────────────────────────────────────────────────────"
  echo ""

  # Note: --gpus all is sufficient for GPU use; DeepPrep auto-detects CUDA
  # No --device flag needed — causes conflicts with --gpus all
  eval docker run --rm \
    ${GPU_FLAG:-} \
    --shm-size 8g \
    --ulimit nofile=65536:65536 \
    -v "${BIDS_DIR}:/input:ro" \
    -v "${OUTPUT_DIR}:/output" \
    -v "${FS_LICENSE}:/fs_license.txt:ro" \
    "$DEEPPREP_IMAGE" \
    /input /output participant \
    --anat_only \
    ${SESSION_FLAG} \
    --fs_license_file /fs_license.txt \
    --cpus "${CPUS}" \
    --memory "${MEMORY_GB}" \
    --skip_bids_validation \
    ${PARTICIPANT_FLAG:-} \
    2>&1 | tee "$LOG_FILE"

  EXIT_CODE=${PIPESTATUS[0]}

  if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ ses-${SESSION} complete"
  else
    echo "❌ ses-${SESSION} failed (exit code $EXIT_CODE)"
    echo "   Check log: $LOG_FILE"
    exit $EXIT_CODE
  fi
done

echo ""
echo "✅ All sessions processed successfully"
echo ""
echo "DeepPrep outputs:"
echo "  FreeSurfer recon: $OUTPUT_DIR/Recon/sub-XXX_ses-YY/"
echo "  QC reports:       $OUTPUT_DIR/QC/sub-XXX_ses-YY.html"
echo ""
echo "Next: python3 scripts/04_structural_analysis.py"
