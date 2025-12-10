#!/usr/bin/env bash
set -euo pipefail
[ -f /opt/rmq/env.sh ] && source /opt/rmq/env.sh || true

VERSION="1.7.0"
PORT="${NODE_EXPORTER_PORT:-9100}"

echo "[install_node_exporter] Installing node_exporter v${VERSION}..."

cd /tmp
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
tar xzf node_exporter-${VERSION}.linux-amd64.tar.gz

sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true
sudo mv node_exporter-${VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=":${PORT}"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl restart node_exporter

echo "[install_node_exporter] node_exporter running on port ${PORT}."
