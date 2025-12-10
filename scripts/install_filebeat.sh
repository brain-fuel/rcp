#!/usr/bin/env bash
set -euo pipefail

echo "[install_filebeat] Installing Filebeat..."

sudo apt-get update -y
sudo apt-get install -y curl gnupg apt-transport-https

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    | sudo gpg --dearmor | sudo tee /usr/share/keyrings/elastic.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
    | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt-get update -y
sudo apt-get install -y filebeat

sudo tee /etc/filebeat/filebeat.yml >/dev/null <<'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/rabbitmq/*.log

output.console:
  enabled: true
EOF

sudo systemctl enable filebeat
sudo systemctl restart filebeat

echo "[install_filebeat] Done."
