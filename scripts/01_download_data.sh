#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# 01_download_data.sh — Download and verify the BIDS dataset
#
# 1. Syncs ds000174 from OpenNeuro's S3 bucket (idempotent — skips files
#    already present at the correct size).
# 2. Verifies every T1w file is at least 5 MB (catches Git-LFS-pointer
#    truncation issues that openneuro-py would silently produce).
# 3. Adds the `sub-` prefix to participant_id in participants.tsv if needed
#    (some OpenNeuro datasets store bare numeric IDs).
#
# Usage:
#   bash scripts/01_download_data.sh           # downloads ds000174
#   DATASET_ID=ds000999 bash scripts/01_download_data.sh   # custom dataset
#
# Output: data/bids/$DATASET_ID/
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET_ID="${DATASET_ID:-ds000174}"
BIDS_DIR="$PROJ_DIR/data/bids/$DATASET_ID"
MIN_SIZE_KB=5000  # 5 MB minimum for a real T1w file

# ── 0. Prerequisites ─────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  echo "[download] Installing AWS CLI..."
  sudo apt-get install -y awscli 2>&1 | tail -3
fi

mkdir -p "$BIDS_DIR"
cd "$BIDS_DIR"

# ── 1. Sync from OpenNeuro S3 ────────────────────────────────────────
echo "[download] Syncing $DATASET_ID from OpenNeuro S3 (incremental)..."
echo "[download] This will only download missing or changed files."
echo ""

# AWS S3 sync is incremental and verifies via checksums.
# --no-sign-request lets us access the public OpenNeuro bucket.
aws s3 sync --no-sign-request "s3://openneuro.org/$DATASET_ID" . 2>&1 | tail -10

echo ""
echo "[download] Final state:"
echo "  Path: $BIDS_DIR"
echo "  Total disk: $(du -sh . | cut -f1)"
echo "  Subjects: $(ls -d sub-* 2>/dev/null | wc -l)"

# ── 2. Verify integrity ──────────────────────────────────────────────
echo ""
echo "[verify] Checking every T1w file is >= ${MIN_SIZE_KB} KB..."
BL_VALID=0; BL_TOTAL=0; FU_VALID=0; FU_TOTAL=0
INVALID_SUBS=()

for sub_dir in sub-*; do
  [ -d "$sub_dir" ] || continue
  for ses in BL FU; do
    t1w=$(find "$sub_dir/ses-$ses/anat" -name "*T1w.nii.gz" 2>/dev/null | head -1)
    if [ -n "$t1w" ] && [ -f "$t1w" ]; then
      size_kb=$(du -k "$t1w" | cut -f1)
      if [ "$ses" == "BL" ]; then
        BL_TOTAL=$((BL_TOTAL+1))
        [ "$size_kb" -gt $MIN_SIZE_KB ] && BL_VALID=$((BL_VALID+1)) || INVALID_SUBS+=("$sub_dir/ses-$ses ($size_kb KB)")
      else
        FU_TOTAL=$((FU_TOTAL+1))
        [ "$size_kb" -gt $MIN_SIZE_KB ] && FU_VALID=$((FU_VALID+1)) || INVALID_SUBS+=("$sub_dir/ses-$ses ($size_kb KB)")
      fi
    fi
  done
done

echo "[verify] BL session: $BL_VALID/$BL_TOTAL subjects have valid T1w (>5MB)"
echo "[verify] FU session: $FU_VALID/$FU_TOTAL subjects have valid T1w (>5MB)"

if [ ${#INVALID_SUBS[@]} -gt 0 ]; then
  echo ""
  echo "[verify] WARNING: ${#INVALID_SUBS[@]} session(s) with undersized T1w files:"
  for s in "${INVALID_SUBS[@]}"; do echo "    $s"; done
  echo ""
  echo "[verify] Re-running S3 sync to fix incomplete files..."
  aws s3 sync --no-sign-request "s3://openneuro.org/$DATASET_ID" . 2>&1 | tail -10
  echo ""
  echo "[verify] Re-checking after sync..."

  BL_VALID=0; FU_VALID=0
  for sub_dir in sub-*; do
    [ -d "$sub_dir" ] || continue
    for ses in BL FU; do
      t1w=$(find "$sub_dir/ses-$ses/anat" -name "*T1w.nii.gz" 2>/dev/null | head -1)
      if [ -n "$t1w" ] && [ -f "$t1w" ]; then
        size_kb=$(du -k "$t1w" | cut -f1)
        if [ "$size_kb" -gt $MIN_SIZE_KB ]; then
          [ "$ses" == "BL" ] && BL_VALID=$((BL_VALID+1)) || FU_VALID=$((FU_VALID+1))
        fi
      fi
    done
  done
  echo "[verify] After re-sync: BL=$BL_VALID, FU=$FU_VALID valid"
fi

# Count subjects with valid data in BOTH sessions
BOTH=$(
  comm -12 \
    <(for f in sub-*/ses-BL/anat/*T1w.nii.gz; do [ -f "$f" ] && [ "$(du -k "$f" | cut -f1)" -gt $MIN_SIZE_KB ] && echo "$f" | cut -d/ -f1; done | sort -u) \
    <(for f in sub-*/ses-FU/anat/*T1w.nii.gz; do [ -f "$f" ] && [ "$(du -k "$f" | cut -f1)" -gt $MIN_SIZE_KB ] && echo "$f" | cut -d/ -f1; done | sort -u)
)
BOTH_COUNT=$(echo "$BOTH" | grep -c . || true)
echo ""
echo "[verify] $BOTH_COUNT subjects have valid T1w data in BOTH BL and FU sessions"
echo "[verify]    Total disk: $(du -sh . | cut -f1)"

# ── 3. Fix participants.tsv format ───────────────────────────────────
echo ""
echo "[fix-tsv] Ensuring participant_id column has sub- prefix..."
PROJ_DIR="$PROJ_DIR" DATASET_ID="$DATASET_ID" \
  python3 "$(dirname "${BASH_SOURCE[0]}")/fix_participants_tsv.py"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " ✅ Dataset $DATASET_ID ready at $BIDS_DIR"
echo "═══════════════════════════════════════════════════════════════"
