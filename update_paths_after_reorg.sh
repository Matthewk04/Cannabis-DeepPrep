#!/usr/bin/env bash
# =============================================================================
# update_paths_after_reorg.sh
# Updates all hardcoded paths in scripts after reorganization
#
# Run AFTER reorganize_repo.sh completes successfully
# =============================================================================
set -euo pipefail

echo "[paths] Updating paths in all code/ scripts..."
echo ""

# ── Update Python scripts ─────────────────────────────────────────────────────
echo "[paths] Fixing Python scripts..."

# 03_group_participants.py
sed -i 's|outputs/analysis|data/processed|g' code/analysis/03_group_participants.py

# 04_structural_analysis.py
sed -i 's|outputs/deepprep|data/derivatives/deepprep|g' code/analysis/04_structural_analysis.py
sed -i 's|outputs/analysis|data/processed|g' code/analysis/04_structural_analysis.py

# 04_functional_analysis.py
sed -i 's|outputs/deepprep|data/derivatives/deepprep|g' code/analysis/04_functional_analysis.py
sed -i 's|outputs/analysis|data/processed|g' code/analysis/04_functional_analysis.py

# 05_visualize_results.py
sed -i 's|outputs/analysis|data/processed|g' code/visualization/05_visualize_results.py
sed -i 's|outputs/figures|data/processed/figures|g' code/visualization/05_visualize_results.py

echo "[paths] ✓ Python scripts updated"

# ── Update Bash scripts ───────────────────────────────────────────────────────
echo "[paths] Fixing Bash scripts..."

# 00_setup.sh — no path changes needed

# 01_download_data.sh
sed -i 's|data/bids/ds000174|data/raw/ds000174|g' code/preprocessing/01_download_data.sh

# 02_run_deepprep_anat.sh
sed -i 's|data/bids/ds000174|data/raw/ds000174|g' code/preprocessing/02_run_deepprep_anat.sh
sed -i 's|outputs/deepprep|data/derivatives/deepprep|g' code/preprocessing/02_run_deepprep_anat.sh
sed -i 's|outputs/analysis|data/processed|g' code/preprocessing/02_run_deepprep_anat.sh

# 02_run_deepprep_bold.sh
sed -i 's|data/bids/|data/raw/|g' code/preprocessing/02_run_deepprep_bold.sh
sed -i 's|outputs/deepprep|data/derivatives/deepprep|g' code/preprocessing/02_run_deepprep_bold.sh

echo "[paths] ✓ Bash scripts updated"
echo ""

# ── Update cross-references between scripts ───────────────────────────────────
echo "[paths] Updating script cross-references (next: messages)..."

# Scripts now reference each other with full relative paths from repo root
sed -i 's|bash scripts/|bash code/preprocessing/|g' code/preprocessing/*.sh code/analysis/*.py code/visualization/*.py 2>/dev/null || true
sed -i 's|python3 scripts/|python3 code/analysis/|g' code/preprocessing/*.sh code/analysis/*.py code/visualization/*.py 2>/dev/null || true
sed -i 's|python3 code/analysis/05_visualize|python3 code/visualization/05_visualize|g' code/analysis/*.py 2>/dev/null || true

echo "[paths] ✓ Cross-references updated"
echo ""
echo "✅ All paths updated. Review code/ files before committing."
