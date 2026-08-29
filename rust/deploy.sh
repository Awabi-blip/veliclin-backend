#!/usr/bin/env bash
set -euo pipefail

KEY="$HOME/vault_decrypted/AWS/veliclin-key.pem"
SERVER="ubuntu@3.67.137.46"

echo "📤 Uploading..."
scp -i "$KEY" \
    target/release/rust \
    "$SERVER:/home/ubuntu/veliclin.new"

echo "🚀 Deploying..."
ssh -i "$KEY" "$SERVER" '
    sudo systemctl stop veliclin &&
    mv /home/ubuntu/veliclin.new /home/ubuntu/veliclin &&
    chmod +x /home/ubuntu/veliclin &&
    sudo systemctl start veliclin &&
    sudo systemctl status veliclin --no-pager
'

echo "✅ Veliclin deployed."
