#!/usr/bin/env bash
# =============================================================================
# 01_download_data.sh — Download ds000174 from OpenNeuro (AWS S3)
#
# ds000174: "T1-weighted structural MRI study of cannabis users"
#   Heavy users N=20, Controls N=22, 3T Philips Intera
#   License: CC BY-NC 4.0
#   NOTE: This dataset contains T1w STRUCTURAL MRI only (no BOLD/fMRI).
#         Use --anat_only flag in DeepPrep (script 02_run_deepprep_anat.sh).
# =============================================================================
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIDS_DIR="$PROJ_DIR/data/bids"
DATASET="ds000174"
S3_PREFIX="s3://openneuro.org/${DATASET}"

echo "============================================================"
echo " Downloading ${DATASET} from OpenNeuro"
echo " Destination: $BIDS_DIR"
echo "============================================================"

# ── Method 1: AWS CLI (fastest — no auth required for OpenNeuro) ──────────────
if command -v aws &>/dev/null; then
  echo "[download] Using AWS CLI (no-sign-request)..."
  aws s3 sync \
    --no-sign-request \
    --exclude "*.git*" \
    "$S3_PREFIX" \
    "$BIDS_DIR/${DATASET}/"
  echo "[download] ✓ AWS CLI sync complete."

# ── Method 2: DataLad ─────────────────────────────────────────────────────────
elif command -v datalad &>/dev/null; then
  echo "[download] Using DataLad..."
  cd "$BIDS_DIR"
  datalad install -r "https://github.com/OpenNeuroDatasets/${DATASET}.git"
  cd "${DATASET}"
  datalad get .
  echo "[download] ✓ DataLad download complete."

# ── Method 3: openneuro-py ────────────────────────────────────────────────────
elif python -c "import openneuro" &>/dev/null 2>&1; then
  echo "[download] Using openneuro-py..."
  python - <<'PYEOF'
import openneuro, os, sys
dest = os.path.join(os.environ.get("BIDS_DIR", "."), "ds000174")
openneuro.download(dataset="ds000174", target_dir=dest)
PYEOF
  echo "[download] ✓ openneuro-py download complete."

# ── Method 4: curl fallback (tarball) ────────────────────────────────────────
else
  echo "[download] Falling back to direct tarball download..."
  TARBALL="$PROJ_DIR/data/ds174_R1.0.0_all_data.tgz"
  curl -L \
    "http://openfmri.s3.amazonaws.com/tarballs/ds174_R1.0.0_all_data.tgz" \
    -o "$TARBALL"
  echo "[download] Extracting tarball..."
  mkdir -p "$BIDS_DIR/${DATASET}"
  tar -xzf "$TARBALL" -C "$BIDS_DIR/${DATASET}" --strip-components=1
  rm "$TARBALL"
  echo "[download] ✓ Tarball download and extraction complete."
fi

# ── Validate BIDS ─────────────────────────────────────────────────────────────
echo ""
echo "[download] Checking BIDS structure..."
BIDS_PATH="$BIDS_DIR/${DATASET}"

if [ -f "$BIDS_PATH/dataset_description.json" ]; then
  echo "[download] ✓ dataset_description.json found"
else
  echo "[download] ⚠ dataset_description.json missing — BIDS may be incomplete"
fi

if [ -d "$BIDS_PATH/sub-01" ] || [ -d "$BIDS_PATH/sub-control01" ]; then
  echo "[download] ✓ Subject directories found"
  echo "[download]   Subjects: $(ls -d "$BIDS_PATH"/sub-* 2>/dev/null | wc -l)"
else
  echo "[download] ⚠ No sub-* directories found yet — check download"
fi

# ── Show modalities available ─────────────────────────────────────────────────
echo ""
echo "[download] Modalities in dataset:"
find "$BIDS_PATH" -name "*.nii.gz" 2>/dev/null | \
  grep -oP '(?<=_)[a-zA-Z0-9]+(?=\.nii\.gz)' | sort | uniq -c | sort -rn | head -20 || true

echo ""
echo "[download] ✅ Download complete."
echo "   Dataset path: $BIDS_PATH"
echo "   Next: bash code/preprocessing/02_run_deepprep_anat.sh"
