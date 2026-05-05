#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# verify_gpu.sh — Verify NVIDIA GPU + Docker pipeline before running DeepPrep
#
# Checks (in order):
#   1. nvidia-smi works on the host
#   2. nvidia-container-toolkit is installed
#   3. CDI spec exists
#   4. `docker run --gpus all` can see the GPU
#   5. DeepPrep image is pulled and usable
#
# Usage:
#   bash scripts/verify_gpu.sh
# ─────────────────────────────────────────────────────────────────────────
set -uo pipefail

DEEPPREP_IMAGE="${DEEPPREP_IMAGE:-pbfslab/deepprep:25.1.0}"
PASS=0
FAIL=0

check() {
    local name="$1"; shift
    if "$@" > /tmp/_check.out 2>&1; then
        echo "  ✓ $name"
        PASS=$((PASS+1))
    else
        echo "  ✗ $name"
        sed 's/^/      /' /tmp/_check.out
        FAIL=$((FAIL+1))
    fi
}

echo "═══════════════════════════════════════════════════════════════"
echo "  GPU + Docker Verification"
echo "═══════════════════════════════════════════════════════════════"

# 1. nvidia-smi on host
echo ""
echo "[1/5] Host NVIDIA driver..."
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1 | sed 's/^/      /'
    check "nvidia-smi works" nvidia-smi -L
else
    echo "  ✗ nvidia-smi not found — install NVIDIA driver first (run 00_setup.sh)"
    FAIL=$((FAIL+1))
fi

# 2. nvidia-container-toolkit
echo ""
echo "[2/5] nvidia-container-toolkit..."
check "nvidia-ctk binary present" command -v nvidia-ctk

# 3. CDI spec
echo ""
echo "[3/5] CDI specification..."
if [ -f /etc/cdi/nvidia.yaml ]; then
    echo "  ✓ /etc/cdi/nvidia.yaml exists"
    PASS=$((PASS+1))
else
    echo "  ✗ /etc/cdi/nvidia.yaml not found"
    echo "      Fix: sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
    FAIL=$((FAIL+1))
fi

# 4. Docker GPU passthrough
echo ""
echo "[4/5] Docker GPU passthrough (this pulls a small CUDA image once)..."
check "docker run --gpus all sees GPU" \
    sudo docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi -L

# 5. DeepPrep image
echo ""
echo "[5/5] DeepPrep image..."
if sudo docker image inspect "$DEEPPREP_IMAGE" &>/dev/null; then
    echo "  ✓ $DEEPPREP_IMAGE present"
    PASS=$((PASS+1))
else
    echo "  ✗ $DEEPPREP_IMAGE not pulled yet"
    echo "      Fix: sudo docker pull $DEEPPREP_IMAGE"
    FAIL=$((FAIL+1))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Result: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════════════════════════"
[ $FAIL -eq 0 ] && exit 0 || exit 1
