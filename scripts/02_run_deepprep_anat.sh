#!/usr/bin/env bash
set -euo pipefail

DEEPPREP_IMAGE="pbfslab/deepprep:25.1.0"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIDS_DIR="$PROJ_DIR/data/bids/ds000174"
OUTPUT_DIR="$PROJ_DIR/outputs/deepprep"
FS_LICENSE="$PROJ_DIR/data/freesurfer/license.txt"
CPUS=4
MEMORY_GB=16

if [ ! -d "$BIDS_DIR" ]; then
  echo "❌ BIDS dataset not found"
  exit 1
fi
if [ ! -f "$FS_LICENSE" ]; then
  echo "❌ FreeSurfer license not found"
  exit 1
fi
mkdir -p "$OUTPUT_DIR" "$PROJ_DIR/logs"

SESSIONS=("BL" "FU")
SUBJECT_LIST=()

if [ "${1:-}" = "--pilot" ]; then
  PILOT_FILE="$PROJ_DIR/outputs/analysis/pilot_subjects.txt"
  readarray -t SUBJECT_LIST < "$PILOT_FILE"
  echo "[deepprep] Pilot mode: ${SUBJECT_LIST[*]}"
fi

GPU_FLAG=""
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null 2>&1; then
  if docker info 2>/dev/null | grep -qi "nvidia"; then
    GPU_FLAG="--gpus all"
    echo "[deepprep] ✓ GPU detected"
  fi
fi

echo ""
echo "============================================================"
echo " DeepPrep 25.1.0 — Session-Separated Processing"
echo "   Subjects: ${#SUBJECT_LIST[@]}"
echo "   Sessions: ${SESSIONS[*]}"
echo "============================================================"
echo ""

# Restore any hidden sessions from previous runs
echo "[SETUP] Restoring any previously hidden sessions..."
for subj in "${SUBJECT_LIST[@]}"; do
  subj=$(echo "$subj" | xargs)
  for ses in BL FU; do
    if [ -d "$BIDS_DIR/sub-${subj}/ses-${ses}.HIDDEN" ]; then
      sudo mv "$BIDS_DIR/sub-${subj}/ses-${ses}.HIDDEN" "$BIDS_DIR/sub-${subj}/ses-${ses}"
    fi
  done
done

# Function to hide sessions
hide_sessions() {
  local session_to_hide=$1
  echo "[SESSION] Hiding all ses-${session_to_hide}..."
  for subj in "${SUBJECT_LIST[@]}"; do
    subj=$(echo "$subj" | xargs)
    local ses_dir="$BIDS_DIR/sub-${subj}/ses-${session_to_hide}"
    if [ -d "$ses_dir" ]; then
      sudo mv "$ses_dir" "${ses_dir}.HIDDEN"
    fi
  done
}

# Function to restore sessions
restore_sessions() {
  local session_to_restore=$1
  echo "[SESSION] Restoring all ses-${session_to_restore}..."
  for subj in "${SUBJECT_LIST[@]}"; do
    subj=$(echo "$subj" | xargs)
    local hidden_dir="$BIDS_DIR/sub-${subj}/ses-${session_to_restore}.HIDDEN"
    if [ -d "$hidden_dir" ]; then
      sudo mv "$hidden_dir" "$BIDS_DIR/sub-${subj}/ses-${session_to_restore}"
    fi
  done
}

# Process each session separately
for SESSION in "${SESSIONS[@]}"; do
  echo ""
  echo "════════════════════════════════════════════════════════════"
  echo " PROCESSING: ses-${SESSION}"
  echo "════════════════════════════════════════════════════════════"
  
  # Hide the OTHER session
  if [ "$SESSION" = "BL" ]; then
    hide_sessions "FU"
  else
    hide_sessions "BL"
  fi
  
  # Build subject list
  SUBJECTS_FOR_DOCKER=""
  for subj in "${SUBJECT_LIST[@]}"; do
    subj=$(echo "$subj" | xargs)
    SUBJECTS_FOR_DOCKER="${SUBJECTS_FOR_DOCKER}${subj} "
  done
  
  LOG_FILE="$PROJ_DIR/logs/deepprep_ses-${SESSION}_$(date +%Y%m%d_%H%M%S).log"
  
  echo "Subjects: ${SUBJECTS_FOR_DOCKER}"
  echo "Log: $LOG_FILE"
  echo ""
  
  # Run DeepPrep
  docker run --rm \
    ${GPU_FLAG} \
    -v "${BIDS_DIR}:/input:ro" \
    -v "${OUTPUT_DIR}:/output" \
    -v "${FS_LICENSE}:/fs_license.txt:ro" \
    "$DEEPPREP_IMAGE" \
    /input /output participant \
    --anat_only \
    --participant_label ${SUBJECTS_FOR_DOCKER} \
    --fs_license_file /fs_license.txt \
    --cpus "${CPUS}" \
    --memory "${MEMORY_GB}" \
    --skip_bids_validation \
    2>&1 | tee "$LOG_FILE"
  
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ ses-${SESSION} failed"
    restore_sessions "BL"
    restore_sessions "FU"
    exit 1
  fi
  
  # Rename outputs to preserve them with session labels
  echo ""
  echo "[OUTPUT] Renaming to include session labels..."
  for subj in "${SUBJECT_LIST[@]}"; do
    subj=$(echo "$subj" | xargs)
    
    # Rename Recon outputs
    if [ -d "$OUTPUT_DIR/Recon/sub-${subj}" ]; then
      sudo mv "$OUTPUT_DIR/Recon/sub-${subj}" "$OUTPUT_DIR/Recon/sub-${subj}_ses-${SESSION}"
      echo "  ✓ Recon: sub-${subj} → sub-${subj}_ses-${SESSION}"
    fi
    
    # Rename QC outputs
    if [ -d "$OUTPUT_DIR/QC/sub-${subj}" ]; then
      sudo mv "$OUTPUT_DIR/QC/sub-${subj}" "$OUTPUT_DIR/QC/sub-${subj}_ses-${SESSION}"
      echo "  ✓ QC:    sub-${subj} → sub-${subj}_ses-${SESSION}"
    fi
  done
  
  # Restore the hidden session
  if [ "$SESSION" = "BL" ]; then
    restore_sessions "FU"
  else
    restore_sessions "BL"
  fi
  
  echo "✅ ses-${SESSION} complete"
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ All sessions processed successfully!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Recon outputs (for analysis):"
ls -d "$OUTPUT_DIR/Recon/sub-"* 2>/dev/null || echo "  (none yet)"
echo ""
echo "QC reports (review before analysis):"
ls -d "$OUTPUT_DIR/QC/sub-"* 2>/dev/null || echo "  (none yet)"
echo ""
echo "Next steps:"
echo "  1. Review QC reports: open outputs/deepprep/QC/sub-*_ses-*/sub-*.html"
echo "  2. Exclude any failed scans"
echo "  3. Extract stats: python3 scripts/04_structural_analysis.py"
