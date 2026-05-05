#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────
# 00_setup.sh — Single-node DeepPrep environment setup
#
# Installs everything needed to run DeepPrep on a single Ubuntu 22.04 node:
#   - System packages (Java 17 for Nextflow, awscli, rsync, etc.)
#   - NVIDIA driver 535-server (if a GPU is detected)
#   - Docker Engine + nvidia-container-toolkit + CDI spec
#   - DeepPrep 25.1.0 image pull
#   - Nextflow 24.x
#   - Python neuroimaging stack
#
# Usage:
#   sudo bash scripts/00_setup.sh
#
# Idempotent: re-running will skip steps already complete.
# Requires: Ubuntu 22.04 LTS, sudo access, internet connectivity.
# ─────────────────────────────────────────────────────────────────────────
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "[setup] Starting DeepPrep environment setup on $(hostname)..."

# ─── 1. System packages (incl. Java 17) ──────────────────────────────
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  curl wget gnupg2 ca-certificates lsb-release \
  apt-transport-https software-properties-common \
  python3 python3-pip python3-venv \
  awscli git unzip openjdk-17-jdk rsync \
  pkg-config libglvnd-dev \
  linux-headers-$(uname -r) 2>&1 | tail -3
echo "[setup] System packages installed"

# Make Java 17 default (Nextflow requires Java 17+)
sudo update-alternatives --install /usr/bin/java java \
  /usr/lib/jvm/java-17-openjdk-amd64/bin/java 1711 2>/dev/null || true
sudo update-alternatives --set java \
  /usr/lib/jvm/java-17-openjdk-amd64/bin/java 2>/dev/null || true
sudo bash -c 'cat > /etc/profile.d/java17.sh << EOF
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=\$JAVA_HOME/bin:\$PATH
EOF'
echo "[setup] Java 17 set as default"

# ─── 2. NVIDIA driver (only on GPU nodes) ────────────────────────────
GPU_PRESENT=false
if lspci 2>/dev/null | grep -qi nvidia; then
  GPU_PRESENT=true
  echo "[setup] NVIDIA GPU detected:"
  lspci | grep -i nvidia | sed 's/^/    /'

  if ! command -v nvidia-smi &>/dev/null; then
    echo "[setup] Installing NVIDIA driver (server/headless)..."
    sudo apt-get install -y nvidia-driver-535-server 2>&1 | tail -3
    sudo modprobe nvidia 2>/dev/null || true
    sudo modprobe nvidia-uvm 2>/dev/null || true
  fi

  if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then
    echo "[setup] NVIDIA driver active:"
    nvidia-smi -L | sed 's/^/    /'
  else
    echo "[setup] WARNING: Driver installed but module not active. Reboot may be needed."
  fi
else
  echo "[setup] No NVIDIA GPU detected — DeepPrep will run on CPU (~10× slower)."
fi

# ─── 3. Docker Engine ────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "[setup] Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin 2>&1 | tail -3
  sudo systemctl enable --now docker
fi
sudo usermod -aG docker "$USER" || true
echo "[setup] Docker installed: $(docker --version)"

# ─── 4. NVIDIA Container Toolkit + CDI ───────────────────────────────
if [ "$GPU_PRESENT" = true ]; then
  if ! dpkg -l | grep -q nvidia-container-toolkit; then
    echo "[setup] Installing nvidia-container-toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
      sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y nvidia-container-toolkit 2>&1 | tail -3
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
  fi

  # Generate CDI spec — required for nvidia-container-toolkit ≥ 1.18
  # Without this, `docker run --gpus all` fails with:
  #   "failed to discover GPU vendor from CDI: no known GPU vendor found"
  if [ ! -f /etc/cdi/nvidia.yaml ]; then
    echo "[setup] Generating CDI spec for NVIDIA..."
    sudo mkdir -p /etc/cdi
    sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>&1 | tail -3
  fi
fi

# ─── 5. Pull DeepPrep image ──────────────────────────────────────────
echo "[setup] Pulling DeepPrep 25.1.0 image (this may take 10-15 min)..."
sudo docker pull pbfslab/deepprep:25.1.0 2>&1 | tail -3
echo "[setup] DeepPrep image ready"

# ─── 6. Nextflow ─────────────────────────────────────────────────────
if ! command -v nextflow &>/dev/null; then
  echo "[setup] Installing Nextflow..."
  cd /tmp
  curl -fsSL https://get.nextflow.io | bash
  sudo mv nextflow /usr/local/bin/
  sudo chmod +x /usr/local/bin/nextflow
fi
echo "[setup] Nextflow ready: $(nextflow -version 2>&1 | grep version | head -1)"

# ─── 7. Python neuroimaging stack ────────────────────────────────────
echo "[setup] Installing Python neuroimaging packages..."
pip install --user --quiet --upgrade \
  nilearn nibabel pandas numpy scipy statsmodels matplotlib seaborn 2>&1 | tail -3
echo "[setup] Python packages installed"

# ─── 8. Summary ──────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo " ✅ Setup complete on $(hostname)"
echo "═══════════════════════════════════════════════════════════════"
echo "  Java:     $(java -version 2>&1 | head -1)"
echo "  Docker:   $(docker --version)"
echo "  Nextflow: $(nextflow -version 2>&1 | grep version | head -1 || echo 'installed')"
if [ "$GPU_PRESENT" = true ]; then
  echo "  GPU:      $(nvidia-smi -L 2>/dev/null | head -1 || echo 'driver loaded')"
fi
echo ""
echo "  Next step: place your FreeSurfer license at"
echo "    data/freesurfer/license.txt"
echo "  Then run:"
echo "    bash scripts/01_download_data.sh"
echo "═══════════════════════════════════════════════════════════════"
