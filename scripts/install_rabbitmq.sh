#!/usr/bin/env bash
set -euo pipefail
[ -f /opt/rmq/env.sh ] && source /opt/rmq/env.sh || true

echo "[install_rabbitmq] Installing RabbitMQ 4.2 on Ubuntu 24.04..."

sudo apt-get update -y
sudo apt-get install -y curl gnupg apt-transport-https lsb-release

curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" \
    | sudo gpg --dearmor | sudo tee /usr/share/keyrings/rabbitmq.gpg >/dev/null

CODENAME="$(lsb_release -sc)"

echo "deb [signed-by=/usr/share/keyrings/rabbitmq.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/ubuntu ${CODENAME} main" \
    | sudo tee /etc/apt/sources.list.d/rabbitmq.list

sudo apt-get update -y
sudo apt-get install -y rabbitmq-server

echo "[install_rabbitmq] Configuring Erlang cookie..."
sudo mkdir -p /var/lib/rabbitmq
if [ -n "${RABBITMQ_ERLANG_COOKIE:-}" ]; then
  echo "${RABBITMQ_ERLANG_COOKIE}" | sudo tee /var/lib/rabbitmq/.erlang.cookie >/dev/null
  sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
  sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie
fi

echo "[install_rabbitmq] Enabling management + Prometheus plugins (if available)..."
sudo rabbitmq-plugins enable --offline rabbitmq_management rabbitmq_prometheus || true

echo "[install_rabbitmq] Creating /etc/rabbitmq/rabbitmq.conf..."
sudo mkdir -p /etc/rabbitmq
sudo tee /etc/rabbitmq/rabbitmq.conf >/dev/null <<EOF
loopback_users.guest = false

listeners.tcp.default = 5672

management.listener.port = 15672
management.listener.ip   = 0.0.0.0

prometheus.tcp.port = ${RABBITMQ_PROM_PORT:-15692}
prometheus.tcp.ip   = 0.0.0.0

cluster_name = ${RABBITMQ_CLUSTER_NAME:-rmq-cluster}

log.default.level = info
log.file = true
log.file.level = info
log.file.rotation = true
log.file.rotation.count = 10
log.file.rotation.size = 20MB
log.file.directory = /var/log/rabbitmq
log.syslog = false
EOF

echo "[install_rabbitmq] Ensuring /var/log/rabbitmq exists..."
sudo mkdir -p /var/log/rabbitmq
sudo chown rabbitmq:rabbitmq /var/log/rabbitmq
sudo chmod 750 /var/log/rabbitmq

echo "[install_rabbitmq] Enabling and starting rabbitmq-server..."
sudo systemctl enable rabbitmq-server
sudo systemctl restart rabbitmq-server

echo "[install_rabbitmq] Done on $(hostname)."
