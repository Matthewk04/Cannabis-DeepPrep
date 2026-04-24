#!/usr/bin/env bash
# =============================================================================
# 02_run_deepprep_anat.sh
# DeepPrep 25.1.0 — Structural-only preprocessing (Track A)
# Platform: Ubuntu 22.04 (Jammy) on FABRIC testbed
#
# Usage:
#   bash scripts/02_run_deepprep_anat.sh --pilot     # 10-subject prototype (5+5)
#   bash scripts/02_run_deepprep_anat.sh sub-01      # single subject
#   bash scripts/02_run_deepprep_anat.sh              # all subjects
#
# --pilot reads the subject list from outputs/analysis/pilot_subjects.txt
# which is written by 03_group_participants.py.
# Run that script first if pilot_subjects.txt doesn't exist yet.
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
PARTICIPANT_FLAG=""
MODE="all"

if [ "${1:-}" = "--pilot" ]; then
  PILOT_FILE="$PROJ_DIR/outputs/analysis/pilot_subjects.txt"
  if [ ! -f "$PILOT_FILE" ]; then
    echo "❌ pilot_subjects.txt not found."
    echo "   Run first: python3 scripts/03_group_participants.py"
    exit 1
  fi
  # Read IDs, join with spaces, pass as --participant_label '001 002 ...'
  PILOT_IDS=$(tr '\n' ' ' < "$PILOT_FILE" | sed 's/[[:space:]]*$//')
  N_PILOT=$(wc -w < "$PILOT_FILE")
  PARTICIPANT_FLAG="--participant_label '${PILOT_IDS}'"
  MODE="pilot (${N_PILOT} subjects)"
  echo "[deepprep] Prototype mode: ${N_PILOT} subjects"
  echo "[deepprep] IDs: ${PILOT_IDS}"

elif [ -n "${1:-}" ] && [ "${1}" != "--pilot" ]; then
  SUB_LABEL="${1#sub-}"
  PARTICIPANT_FLAG="--participant_label ${SUB_LABEL}"
  MODE="single subject: sub-${SUB_LABEL}"
  echo "[deepprep] Single-subject mode: sub-${SUB_LABEL}"

else
  N_SUBS=$(ls -d "$BIDS_DIR"/sub-* 2>/dev/null | wc -l)
  echo "[deepprep] Batch mode: all ${N_SUBS} subjects"
fi

# ── Runtime estimate ──────────────────────────────────────────────────────────
# Rough estimates per subject: CPU ~100 min, GPU T4 ~14 min, GPU RTX6000 ~9 min
if   command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
  MINS_PER_SUB=12; RUNTIME_DESC="GPU"
else
  MINS_PER_SUB=100; RUNTIME_DESC="CPU"
fi

if [ "$MODE" = "pilot (10 subjects)" ] || [[ "$MODE" == pilot* ]]; then
  N_EST=$(wc -w < "$PROJ_DIR/outputs/analysis/pilot_subjects.txt" 2>/dev/null || echo 10)
  EST_HOURS=$(( N_EST * MINS_PER_SUB / 60 ))
  EST_MINS=$(( N_EST * MINS_PER_SUB % 60 ))
  echo "[deepprep] Estimated runtime on ${RUNTIME_DESC}: ~${EST_HOURS}h ${EST_MINS}m"
  if [ "$RUNTIME_DESC" = "CPU" ]; then
    echo "[deepprep] 💡 Tip: run inside tmux/screen so SSH disconnect doesn't kill the job:"
    echo "             tmux new -s deepprep"
    echo "             bash scripts/02_run_deepprep_anat.sh --pilot"
    echo "             # Detach: Ctrl+B then D    Reattach: tmux attach -t deepprep"
  fi
  echo ""
fi

# ── GPU / CPU detection ───────────────────────────────────────────────────────
GPU_FLAG=""
DEVICE_FLAG=""

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
  if docker info 2>/dev/null | grep -qi "nvidia\|Runtimes.*nvidia"; then
    GPU_FLAG="--gpus all"
    echo "[deepprep] ✓ GPU detected + Docker nvidia runtime configured"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader \
      | sed 's/^/             /'
  else
    echo "[deepprep] ⚠  NVIDIA driver present but Docker nvidia runtime not configured."
    echo "            Run: sudo nvidia-ctk runtime configure --runtime=docker"
    echo "                 sudo systemctl restart docker"
    echo "            Continuing with CPU fallback."
    DEVICE_FLAG="--device cpu"
  fi
else
  echo "[deepprep] No GPU found — CPU mode."
  DEVICE_FLAG="--device cpu"
fi

# ── Run ───────────────────────────────────────────────────────────────────────
LOG_FILE="$PROJ_DIR/logs/deepprep_anat_$(date +%Y%m%d_%H%M%S).log"
echo ""
echo "============================================================"
echo " DeepPrep 25.1.0  |  Mode: ${MODE}"
echo "   Input:  $BIDS_DIR"
echo "   Output: $OUTPUT_DIR"
echo "   Log:    $LOG_FILE"
echo "============================================================"
echo ""

# eval needed because PARTICIPANT_FLAG may contain quoted spaces
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
  --fs_license_file /fs_license.txt \
  --cpus "${CPUS}" \
  --memory "${MEMORY_GB}" \
  --skip_bids_validation \
  ${DEVICE_FLAG:-} \
  ${PARTICIPANT_FLAG:-} \
  2>&1 | tee "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
echo ""
if [ $EXIT_CODE -eq 0 ]; then
  COMPLETED=$(ls -d "$OUTPUT_DIR"/sub-* 2>/dev/null | wc -l)
  echo "✅ DeepPrep complete. Derivatives written for ${COMPLETED} subject(s)."
  echo "   Next: python3 scripts/04_structural_analysis.py"
else
  echo "❌ DeepPrep exited with code $EXIT_CODE — check log: $LOG_FILE"
  exit $EXIT_CODE
fi
