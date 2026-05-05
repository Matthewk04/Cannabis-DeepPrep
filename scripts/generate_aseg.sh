#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# generate_aseg.sh — Post-hoc aseg.stats generation
#
# DeepPrep 25.1.0 produces segmentation volumes (aseg.mgz, aparc+aseg.mgz)
# but does NOT run `mri_segstats` to convert them into the FreeSurfer
# `aseg.stats` text file the analysis scripts depend on.
#
# This script runs `mri_segstats` inside the DeepPrep container against
# every existing aseg.mgz, producing the standard 121-line aseg.stats.
#
# Usage:
#   bash scripts/generate_aseg.sh
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECON_DIR="$PROJ_DIR/outputs/deepprep/Recon"
FS_LICENSE="$PROJ_DIR/data/freesurfer/license.txt"
DEEPPREP_IMAGE="${DEEPPREP_IMAGE:-pbfslab/deepprep:25.1.0}"

[ -d "$RECON_DIR" ] || { echo "ERROR: Recon dir not found: $RECON_DIR"; exit 1; }
[ -f "$FS_LICENSE" ] || { echo "ERROR: FreeSurfer license not found: $FS_LICENSE"; exit 1; }

TOTAL=$(ls -d "$RECON_DIR"/sub-*_ses-* 2>/dev/null | wc -l)
echo "Found $TOTAL subject-session directories"
COUNT=0

for sub_dir in "$RECON_DIR"/sub-*_ses-*; do
    [ -d "$sub_dir" ] || continue
    sub_name=$(basename "$sub_dir")
    COUNT=$((COUNT + 1))

    if [ -f "$sub_dir/stats/aseg.stats" ]; then
        echo "[$COUNT/$TOTAL] $sub_name: aseg.stats already present, skipping"
        continue
    fi

    if [ ! -f "$sub_dir/mri/aseg.mgz" ]; then
        echo "[$COUNT/$TOTAL] $sub_name: aseg.mgz NOT FOUND, skipping"
        continue
    fi

    echo "[$COUNT/$TOTAL] $sub_name: generating aseg.stats..."
    sudo docker run --rm \
        -v "$PROJ_DIR/outputs/deepprep:/output" \
        -v "$FS_LICENSE:/opt/freesurfer/license.txt:ro" \
        --entrypoint /bin/bash \
        "$DEEPPREP_IMAGE" \
        -c "export FREESURFER_HOME=/opt/freesurfer && \
            export SUBJECTS_DIR=/output/Recon && \
            source /opt/freesurfer/SetUpFreeSurfer.sh > /dev/null 2>&1 && \
            cd /output/Recon/$sub_name && \
            mri_segstats \
              --seg /output/Recon/$sub_name/mri/aseg.mgz \
              --sum /output/Recon/$sub_name/stats/aseg.stats \
              --pv /output/Recon/$sub_name/mri/norm.mgz \
              --empty --brainmask /output/Recon/$sub_name/mri/brainmask.mgz \
              --brain-vol-from-seg --excludeid 0 \
              --excl-ctxgmwm --supratent --subcortgray \
              --in /output/Recon/$sub_name/mri/norm.mgz \
              --in-intensity-name norm --in-intensity-units MR \
              --etiv --surf-wm-vol --surf-ctx-vol --totalgray --euler \
              --ctab /opt/freesurfer/ASegStatsLUT.txt \
              --subject $sub_name 2>&1 | tail -3"
done

# Fix ownership (Docker writes as root)
sudo chown -R "$USER:$USER" "$PROJ_DIR/outputs/deepprep" 2>/dev/null || true

echo ""
echo "Summary on $(hostname):"
ls "$RECON_DIR"/sub-*_ses-*/stats/aseg.stats 2>/dev/null | wc -l | xargs -I {} echo "  aseg.stats files: {}"
