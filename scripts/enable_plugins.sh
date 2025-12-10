#!/usr/bin/env bash
set -euo pipefail

if [ -f /opt/rmq/env.sh ]; then
  # shellcheck disable=SC1091
  source /opt/rmq/env.sh
fi

PLUGINS=(
  rabbitmq_management
  rabbitmq_auth_backend_ldap
  rabbitmq_shovel
  rabbitmq_shovel_management
  rabbitmq_prometheus
  rabbitmq_consistent_hash_exchange
  rabbitmq_federation
  rabbitmq_federation_management
  rabbitmq_amqp1_0
)

echo "[enable_plugins] Ensuring RabbitMQ service is running..."
sudo systemctl start rabbitmq-server

echo "[enable_plugins] Enabling required plugins..."
for p in "${PLUGINS[@]}"; do
  echo "  -> enabling ${p} ..."
  if ! sudo rabbitmq-plugins enable --offline "${p}" >/dev/null 2>&1; then
    echo "     [WARN] Failed to enable ${p} (may not exist in this version or already enabled)."
  fi
done

echo
echo "[enable_plugins] Enabled plugins:"
sudo rabbitmq-plugins list -E

echo "[enable_plugins] Done."
