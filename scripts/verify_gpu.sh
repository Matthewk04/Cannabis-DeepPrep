#!/usr/bin/env bash
# =============================================================================
# verify_gpu.sh — Verify GPU is available and accessible from Docker
# Run this BEFORE starting DeepPrep to confirm your RTX 6000 is working
# =============================================================================
set -euo pipefail

echo "════════════════════════════════════════════════════════════"
echo " GPU Verification for DeepPrep on FABRIC Testbed"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── 1. Check if nvidia-smi exists on host ─────────────────────────────────────
echo "[1/5] Checking for NVIDIA driver on host..."
if command -v nvidia-smi &>/dev/null; then
  echo "      ✅ nvidia-smi found"
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
else
  echo "      ❌ nvidia-smi not found"
  echo "      Install driver: sudo apt install nvidia-driver-535"
  exit 1
fi
echo ""

# ── 2. Check Docker is installed ──────────────────────────────────────────────
echo "[2/5] Checking Docker installation..."
if command -v docker &>/dev/null; then
  DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
  echo "      ✅ Docker version $DOCKER_VER"
else
  echo "      ❌ Docker not found"
  exit 1
fi
echo ""

# ── 3. Check nvidia-container-toolkit ────────────────────────────────────────
echo "[3/5] Checking nvidia-container-toolkit..."
if dpkg -l | grep -q nvidia-container-toolkit; then
  echo "      ✅ nvidia-container-toolkit installed"
else
  echo "      ❌ nvidia-container-toolkit not installed"
  echo "      Install: see code/preprocessing/00_setup.sh"
  exit 1
fi
echo ""

# ── 4. Check Docker daemon nvidia runtime ─────────────────────────────────────
echo "[4/5] Checking Docker daemon nvidia runtime..."
if docker info 2>/dev/null | grep -qi "nvidia\|Runtimes.*nvidia"; then
  echo "      ✅ Docker daemon configured with nvidia runtime"
else
  echo "      ⚠️  Docker daemon NOT configured for nvidia runtime"
  echo "      Fix:"
  echo "        sudo nvidia-ctk runtime configure --runtime=docker"
  echo "        sudo systemctl restart docker"
  echo ""
  exit 1
fi
echo ""

# ── 5. GPU smoke test inside Docker ───────────────────────────────────────────
echo "[5/5] Testing GPU access inside Docker container..."
if docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
  echo "      ✅ GPU accessible inside Docker containers"
else
  echo "      ❌ GPU test failed"
  echo "      Troubleshoot:"
  echo "        sudo nvidia-ctk runtime configure --runtime=docker"
  echo "        sudo systemctl restart docker"
  echo "        docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi"
  exit 1
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════"
echo " ✅ GPU verification complete"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Your RTX 6000 is ready for DeepPrep."
echo ""
echo "Expected DeepPrep performance:"
echo "  • ~9 minutes per subject (structural only, --anat_only)"
echo "  • ~12 minutes per subject (full fMRI pipeline)"
echo ""
echo "Next: bash scripts/02_run_deepprep_anat.sh --pilot"
