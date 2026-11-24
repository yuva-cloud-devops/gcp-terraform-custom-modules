#!/bin/bash
set -euo pipefail

echo "===> [Custom VM Bootstrap] Initializing at $(date)"
apt-get update -y
apt-get install -y htop net-tools curl jq git

if ! id -u opsadmin >/dev/null 2>&1; then
  useradd -m -s /bin/bash opsadmin
  usermod -aG sudo opsadmin
  echo "opsadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-opsadmin
  chmod 0440 /etc/sudoers.d/99-opsadmin
fi
