#!/usr/bin/env bash
# =============================================================================
# MASTER_REORG.sh
# Complete repository reorganization orchestrator
#
# Runs all reorganization steps in correct order with safety checks
# Usage: cd ~/Cannabis-DeepPrep && bash MASTER_REORG.sh
# =============================================================================
set -euo pipefail

echo "════════════════════════════════════════════════════════════════════"
echo " Cannabis-DeepPrep Repository Reorganization"
echo " Following neuroimaging research best practices"
echo "════════════════════════════════════════════════════════════════════"
echo ""

# ── Safety check ──────────────────────────────────────────────────────────────
if [ ! -f "reorganize_repo.sh" ] || [ ! -f "update_paths_after_reorg.sh" ]; then
  echo "❌ Required scripts not found in current directory."
  echo "   Expected: reorganize_repo.sh, update_paths_after_reorg.sh"
  echo "   Make sure you're in the repo root."
  exit 1
fi

if [ ! -d ".git" ]; then
  echo "⚠  This doesn't appear to be a git repository."
  echo "   Initialize git first:"
  echo "     git init"
  echo "     git add -A"
  echo "     git commit -m 'Initial commit before reorganization'"
  echo ""
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# ── Pre-flight checklist ──────────────────────────────────────────────────────
echo "Pre-flight checklist:"
echo "  [1] Have you committed all current work to git?"
echo "  [2] Have you backed up any large data files not in git?"
echo "  [3] Are you ready to restructure the entire repo?"
echo ""
read -p "Proceed with reorganization? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted. No changes made."
  exit 0
fi

# ── Step 1: Reorganize directory structure ───────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Step 1/3: Reorganizing directory structure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash reorganize_repo.sh
echo ""

# ── Step 2: Update paths in all scripts ──────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Step 2/3: Updating paths in scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash update_paths_after_reorg.sh
echo ""

# ── Step 3: Replace README ────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Step 3/3: Installing new README"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f "README.md" ]; then
  mv README.md README_old.md
  echo "[readme] Backed up old README → README_old.md"
fi
mv README_new.md README.md
echo "[readme] ✓ Installed new research-grade README.md"
echo ""

# ── Final summary ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " ✅ Reorganization complete!"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "Directory structure:"
tree -L 2 -a --dirsfirst 2>/dev/null || find . -maxdepth 2 -type d | sort
echo ""
echo "New files created:"
echo "  ├── docs/methods.md"
echo "  ├── docs/results.md"
echo "  ├── notebooks/exploratory_analysis.ipynb"
echo "  ├── env/requirements.txt"
echo "  ├── env/conda_environment.yml"
echo "  ├── .gitignore"
echo "  ├── LICENSE (MIT)"
echo "  └── README.md (comprehensive)"
echo ""
echo "Old files renamed:"
echo "  └── README_old.md (backup)"
echo ""
echo "Next steps:"
echo "  1. Review the changes:  git diff"
echo "  2. Test one script to verify paths:  bash code/preprocessing/00_setup.sh --help || true"
echo "  3. Stage all changes:  git add -A"
echo "  4. Commit:  git commit -m 'Reorganize repo to follow neuroimaging research best practices'"
echo "  5. Push to GitHub:  git push origin main"
echo ""
echo "GitHub repo improvements to make manually:"
echo "  • Add repository description: 'Cannabis neuroimaging analysis using DeepPrep'"
echo "  • Add topics: neuroimaging, fmri, deepprep, cannabis, structural-mri"
echo "  • Enable GitHub Pages from /docs folder (optional)"
echo ""
