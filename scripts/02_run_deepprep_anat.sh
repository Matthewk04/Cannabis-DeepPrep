#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# 02_run_deepprep_anat.sh — Run DeepPrep structural preprocessing
#
# Runs DeepPrep one (subject, session) at a time on the local Docker host,
# using the "session hiding" workaround for ds000174's voxel-size mismatch
# between BL (1×1×1 mm) and FU (0.88×1.2×0.88 mm).
#
# Usage:
#   bash scripts/02_run_deepprep_anat.sh sub-101            # both BL and FU
#   bash scripts/02_run_deepprep_anat.sh sub-101 BL         # baseline only
#   bash scripts/02_run_deepprep_anat.sh sub-101 FU         # follow-up only
#   bash scripts/02_run_deepprep_anat.sh --pilot            # all pilot subjects, both sessions
#
# Outputs:
#   outputs/deepprep/Recon/sub-NNN_ses-XX/   — FreeSurfer-compatible derivatives
#   outputs/deepprep/QC/sub-NNN_ses-XX.html  — interactive QC report
#
# Bugs handled:
#   • Voxel-size mismatch between sessions (DeepPrep 25.1.0 has no --session_label flag)
#   • DeepPrep's --participant_label only accepts one subject (others must be hidden)
#   • Output directories are renamed to include _ses-XX so both sessions can co-exist
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET_ID="${DATASET_ID:-ds000174}"
BIDS_DIR="$PROJ_DIR/data/bids/$DATASET_ID"
OUTPUT_DIR="$PROJ_DIR/outputs/deepprep"
FS_LICENSE="$PROJ_DIR/data/freesurfer/license.txt"
LOG_DIR="$PROJ_DIR/logs"
DEEPPREP_IMAGE="${DEEPPREP_IMAGE:-pbfslab/deepprep:25.1.0}"
DOCKER_CPUS="${DOCKER_CPUS:-8}"
DOCKER_MEMORY_GB="${DOCKER_MEMORY_GB:-12}"

# ── Argument parsing ─────────────────────────────────────────────────
if [ $# -lt 1 ]; then
    echo "Usage: $0 <sub-NNN | --pilot> [BL|FU]"
    echo ""
    echo "  sub-NNN   Process this subject (defaults to BOTH sessions)"
    echo "  --pilot   Process every subject in outputs/analysis/pilot_subjects.txt"
    echo "  BL | FU   Optional: process only this session"
    exit 1
fi

SUBJECT_ARG="$1"
SESSIONS=("${2:-BL}" "${2:-FU}")
# Dedupe sessions if user passed only BL or only FU
if [ -n "${2:-}" ]; then
    SESSIONS=("$2")
fi

# ── Sanity checks ────────────────────────────────────────────────────
[ -d "$BIDS_DIR" ] || { echo "ERROR: BIDS dir not found: $BIDS_DIR"; exit 1; }
[ -f "$FS_LICENSE" ] || { echo "ERROR: FreeSurfer license not found: $FS_LICENSE"; exit 1; }
mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# Build list of subjects to process
if [ "$SUBJECT_ARG" == "--pilot" ]; then
    PILOT_TXT="$PROJ_DIR/outputs/analysis/pilot_subjects.txt"
    [ -f "$PILOT_TXT" ] || { echo "ERROR: $PILOT_TXT not found. Run 03_group_participants.py first."; exit 1; }
    SUBJECTS=()
    while IFS= read -r line; do
        line="${line//[$'\t\r\n ']/}"
        [ -n "$line" ] && SUBJECTS+=("sub-$line")
    done < "$PILOT_TXT"
else
    SUBJECTS=("$SUBJECT_ARG")
fi

echo "═══════════════════════════════════════════════════════════════"
echo "  DeepPrep run on $(hostname)"
echo "  Dataset:  $DATASET_ID"
echo "  Subjects: ${SUBJECTS[*]}"
echo "  Sessions: ${SESSIONS[*]}"
echo "═══════════════════════════════════════════════════════════════"

# ── Cleanup trap — restore any hidden directories on exit ────────────
restore_hidden() {
    for d in "$BIDS_DIR"/sub-*.NOTPILOT; do
        [ -d "$d" ] && sudo mv "$d" "${d%.NOTPILOT}"
    done
    for sub_dir in "$BIDS_DIR"/sub-*; do
        [ -d "$sub_dir" ] || continue
        for ses in BL FU; do
            [ -d "$sub_dir/ses-${ses}.HIDDEN" ] && sudo mv "$sub_dir/ses-${ses}.HIDDEN" "$sub_dir/ses-${ses}"
        done
    done
}
trap restore_hidden EXIT

# ── Main loop ────────────────────────────────────────────────────────
for SUB_FULL in "${SUBJECTS[@]}"; do
    SUB_NUM="${SUB_FULL#sub-}"
    [ -d "$BIDS_DIR/$SUB_FULL" ] || { echo "[skip] $SUB_FULL: BIDS directory not found"; continue; }

    for SESSION in "${SESSIONS[@]}"; do
        OUT_DIR_NAME="${SUB_FULL}_ses-${SESSION}"
        OTHER_SESSION="FU"; [ "$SESSION" == "FU" ] && OTHER_SESSION="BL"

        # Skip if already done
        if [ -f "$OUTPUT_DIR/Recon/$OUT_DIR_NAME/stats/lh.aparc.stats" ]; then
            echo "[skip] $OUT_DIR_NAME already processed"
            continue
        fi

        # Skip if subject has no valid T1w in this session
        if ! find "$BIDS_DIR/$SUB_FULL/ses-$SESSION/anat" -name "*T1w.nii.gz" 2>/dev/null | grep -q .; then
            echo "[skip] $SUB_FULL ses-$SESSION: no T1w file"
            continue
        fi

        echo ""
        echo ">>> Processing $SUB_FULL ses-$SESSION at $(date) <<<"
        LOGFILE="$LOG_DIR/deepprep_anat_${SUB_FULL}_ses-${SESSION}_$(date +%Y%m%d_%H%M%S).log"

        # Hide other session for this subject (prevents anat_motioncor voxel mismatch)
        if [ -d "$BIDS_DIR/$SUB_FULL/ses-$OTHER_SESSION" ]; then
            sudo mv "$BIDS_DIR/$SUB_FULL/ses-$OTHER_SESSION" "$BIDS_DIR/$SUB_FULL/ses-${OTHER_SESSION}.HIDDEN"
        fi

        # Hide all other subjects (DeepPrep --participant_label only takes one)
        for sub_dir in "$BIDS_DIR"/sub-*; do
            [ -d "$sub_dir" ] || continue
            sn=$(basename "$sub_dir")
            if [ "$sn" != "$SUB_FULL" ] && [[ "$sn" != *.HIDDEN ]] && [[ "$sn" != *.NOTPILOT ]]; then
                sudo mv "$sub_dir" "${sub_dir}.NOTPILOT"
            fi
        done

        # Run DeepPrep (anatomical only)
        sudo docker run --rm --gpus all --shm-size 4g \
            -v "$BIDS_DIR:/input:ro" \
            -v "$OUTPUT_DIR:/output" \
            -v "$FS_LICENSE:/fs_license.txt:ro" \
            "$DEEPPREP_IMAGE" \
            /input /output participant \
            --participant_label "$SUB_NUM" \
            --anat_only \
            --fs_license_file /fs_license.txt \
            --cpus "$DOCKER_CPUS" --memory "$DOCKER_MEMORY_GB" \
            --skip_bids_validation 2>&1 | tee "$LOGFILE" | tail -10

        # Restore everything we hid
        restore_hidden

        # Rename output to include session label
        if [ -d "$OUTPUT_DIR/Recon/$OUT_DIR_NAME" ]; then
            sudo mv "$OUTPUT_DIR/Recon/$OUT_DIR_NAME" "$OUTPUT_DIR/Recon/${OUT_DIR_NAME}.old_$(date +%s)"
        fi
        if [ -d "$OUTPUT_DIR/Recon/$SUB_FULL" ]; then
            sudo mv "$OUTPUT_DIR/Recon/$SUB_FULL" "$OUTPUT_DIR/Recon/$OUT_DIR_NAME"
        fi
        if [ -d "$OUTPUT_DIR/QC/$SUB_FULL" ]; then
            sudo mv "$OUTPUT_DIR/QC/$SUB_FULL" "$OUTPUT_DIR/QC/$OUT_DIR_NAME"
        fi

        echo ">>> Completed $SUB_FULL ses-$SESSION at $(date) <<<"
    done
done

# Fix ownership of outputs (Docker writes as root)
sudo chown -R "$USER:$USER" "$OUTPUT_DIR" 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " ✅ All processing complete on $(hostname)"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Next step: generate aseg.stats files (DeepPrep doesn't run mri_segstats):"
echo "    bash scripts/generate_aseg.sh"
echo ""
echo "  Then run analysis:"
echo "    python3 scripts/04_structural_analysis_longitudinal.py"
