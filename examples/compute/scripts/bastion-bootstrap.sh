#!/bin/bash
set -euo pipefail

echo "===> [Bastion Bootstrap] Initializing at $(date)"
apt-get update -y
apt-get install -y nginx curl jq net-tools

cat << 'EOF' > /var/www/html/index.html
<h1>Production Web App - Bastion Host $(hostname)</h1>
EOF

systemctl restart nginx
systemctl enable nginx
