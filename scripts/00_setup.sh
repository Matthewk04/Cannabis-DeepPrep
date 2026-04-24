#!/usr/bin/env bash
# =============================================================================
# 00_setup.sh — Environment setup for Ubuntu 22.04 (Jammy) + DeepPrep 25.1.0
#
# What this script does:
#   1. Verifies Ubuntu 22.04 (Jammy)
#   2. Installs/verifies Docker Engine (CE) for Jammy
#   3. Installs/verifies NVIDIA Container Toolkit for Ubuntu 22.04
#      (libnvidia-container via nvidia's signed apt repo)
#   4. Verifies GPU is visible inside Docker
#   5. Pulls pbfslab/deepprep:25.1.0
#   6. Installs Python 3.10 analysis dependencies
#   7. Creates project directory tree
# =============================================================================
set -euo pipefail

DEEPPREP_IMAGE="pbfslab/deepprep:25.1.0"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── 0. Confirm Ubuntu 22.04 ───────────────────────────────────────────────────
echo "============================================================"
echo " Environment setup — Ubuntu 22.04 + DeepPrep 25.1.0"
echo "============================================================"

if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "[setup] OS: $PRETTY_NAME"
  if [[ "$VERSION_ID" != "22.04" ]]; then
    echo "⚠  Expected Ubuntu 22.04 but detected $VERSION_ID."
    echo "   Proceeding anyway — some steps may need adjustment."
  else
    echo "[setup] ✓ Ubuntu 22.04 (Jammy) confirmed"
  fi
fi

# ── 1. System packages ────────────────────────────────────────────────────────
echo ""
echo "[setup] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  curl wget gnupg2 ca-certificates lsb-release \
  apt-transport-https software-properties-common \
  python3 python3-pip python3-venv \
  awscli git unzip 2>/dev/null
echo "[setup] ✓ System packages installed"

# ── 2. Docker Engine ──────────────────────────────────────────────────────────
echo ""
if command -v docker &>/dev/null; then
  DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
  echo "[setup] ✓ Docker already installed: v${DOCKER_VER}"
else
  echo "[setup] Installing Docker Engine for Ubuntu 22.04 (Jammy)..."

  # Official Docker apt repo for jammy
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
     https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  # Allow current user to run docker without sudo
  sudo usermod -aG docker "$USER"
  echo "[setup] ✓ Docker installed."
  echo "         ⚠ Log out and back in (or run: newgrp docker) for group change."
fi

# ── 3. NVIDIA Container Toolkit (Ubuntu 22.04 / Jammy path) ──────────────────
echo ""
echo "[setup] Checking NVIDIA GPU + Container Toolkit..."

if ! command -v nvidia-smi &>/dev/null; then
  echo "[setup] ⚠  nvidia-smi not found — no NVIDIA driver detected on this node."
  echo "         DeepPrep will fall back to CPU mode (significantly slower)."
  echo "         To install the driver on Ubuntu 22.04:"
  echo "           ubuntu-drivers autoinstall   # or: sudo apt install nvidia-driver-535"
  GPU_PRESENT=false
else
  GPU_PRESENT=true
  echo "[setup] ✓ NVIDIA driver found:"
  nvidia-smi --query-gpu=name,driver_version,memory.total \
    --format=csv,noheader 2>/dev/null | sed 's/^/           /'
fi

if $GPU_PRESENT; then
  # Package name on Ubuntu 22.04 is nvidia-container-toolkit
  if dpkg -l | grep -q "nvidia-container-toolkit"; then
    echo "[setup] ✓ nvidia-container-toolkit already installed"
  else
    echo "[setup] Installing NVIDIA Container Toolkit (Ubuntu 22.04 Jammy)..."

    # NVIDIA signed repo — note: use 'stable' channel, jammy distribution
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    curl -s -L \
      https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    sudo apt-get update -qq
    sudo apt-get install -y nvidia-container-toolkit

    # Configure the Docker daemon to use the nvidia runtime
    # On Ubuntu 22.04 this writes to /etc/docker/daemon.json
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    echo "[setup] ✓ NVIDIA Container Toolkit installed"
    echo "         Docker daemon configured with nvidia runtime"
  fi

  # Smoke-test: GPU visible inside a container
  echo "[setup] Testing GPU inside Docker..."
  if docker run --rm --gpus all \
       nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi -L 2>/dev/null; then
    echo "[setup] ✓ GPU confirmed accessible inside Docker"
  else
    echo "[setup] ⚠  GPU not visible inside Docker. Troubleshoot steps:"
    echo "           sudo nvidia-ctk runtime configure --runtime=docker"
    echo "           sudo systemctl restart docker"
    echo "           docker run --rm --gpus all ubuntu nvidia-smi"
  fi
fi

# ── 4. Pull DeepPrep 25.1.0 ──────────────────────────────────────────────────
echo ""
echo "[setup] Checking DeepPrep image: $DEEPPREP_IMAGE"
if docker image inspect "$DEEPPREP_IMAGE" &>/dev/null; then
  SIZE=$(docker image inspect "$DEEPPREP_IMAGE" \
         --format='{{.Size}}' | awk '{printf "%.1f GB", $1/1e9}')
  echo "[setup] ✓ $DEEPPREP_IMAGE already present (~${SIZE})"
else
  echo "[setup] Pulling $DEEPPREP_IMAGE (~20 GB — may take several minutes)..."
  docker pull "$DEEPPREP_IMAGE"
  echo "[setup] ✓ $DEEPPREP_IMAGE pulled successfully"
fi

echo "[setup] Image digest:"
docker inspect "$DEEPPREP_IMAGE" --format='  {{.RepoDigests}}' 2>/dev/null || true

# ── 5. Python 3.10 environment ────────────────────────────────────────────────
# Ubuntu 22.04 ships Python 3.10.x by default; no PPA needed
echo ""
PY_VER=$(python3 --version 2>&1)
echo "[setup] $PY_VER (system)"

# Upgrade pip — Ubuntu 22.04's bundled pip is often 22.x, upgrade to latest
python3 -m pip install --upgrade pip --quiet

echo "[setup] Installing neuroimaging analysis libraries..."
python3 -m pip install --quiet \
  "nilearn>=0.10" \
  "nibabel>=5.0" \
  "pandas>=2.0" \
  "numpy>=1.24" \
  "matplotlib>=3.7" \
  "scipy>=1.11" \
  "seaborn>=0.13" \
  "statsmodels>=0.14" \
  "openneuro-py"

echo "[setup] ✓ Python packages installed:"
python3 -c "
import nilearn, nibabel, pandas, numpy, scipy, matplotlib
print(f'  nilearn   {nilearn.__version__}')
print(f'  nibabel   {nibabel.__version__}')
print(f'  pandas    {pandas.__version__}')
print(f'  numpy     {numpy.__version__}')
print(f'  scipy     {scipy.__version__}')
print(f'  matplotlib {matplotlib.__version__}')
"

# ── 6. Project directories ────────────────────────────────────────────────────
echo ""
echo "[setup] Creating project directory structure under: $PROJ_DIR"
mkdir -p "$PROJ_DIR/data/bids"
mkdir -p "$PROJ_DIR/data/freesurfer"
mkdir -p "$PROJ_DIR/outputs/deepprep"
mkdir -p "$PROJ_DIR/outputs/analysis/structural"
mkdir -p "$PROJ_DIR/outputs/analysis/functional"
mkdir -p "$PROJ_DIR/outputs/figures"
mkdir -p "$PROJ_DIR/logs"
echo "[setup] ✓ Directories created"

# ── 7. FreeSurfer license reminder ───────────────────────────────────────────
FS_LICENSE="$PROJ_DIR/data/freesurfer/license.txt"
echo ""
if [ -f "$FS_LICENSE" ]; then
  echo "[setup] ✓ FreeSurfer license found at $FS_LICENSE"
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  ACTION REQUIRED: FreeSurfer license not found."
  echo ""
  echo "  1. Register (free) at:"
  echo "     https://surfer.nmr.mgh.harvard.edu/registration.html"
  echo ""
  echo "  2. Copy license.txt to:"
  echo "     $FS_LICENSE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

echo ""
echo "✅ Setup complete."
echo "   Next: bash scripts/01_download_data.sh"
