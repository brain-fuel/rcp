#!/usr/bin/env bash
set -euo pipefail
[ -f /opt/rmq/env.sh ] && source /opt/rmq/env.sh || true

RABBITMQ_PROM_PORT="${RABBITMQ_PROM_PORT:-15692}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"

echo "[validate_prometheus] Checking RabbitMQ metrics on port ${RABBITMQ_PROM_PORT}..."
curl -sf "http://localhost:${RABBITMQ_PROM_PORT}/metrics" | head -20 || {
  echo "[validate_prometheus] FAILED to fetch RabbitMQ metrics"
}

echo "[validate_prometheus] Checking node_exporter metrics on port ${NODE_EXPORTER_PORT}..."
curl -sf "http://localhost:${NODE_EXPORTER_PORT}/metrics" | head -20 || {
  echo "[validate_prometheus] FAILED to fetch node_exporter metrics"
}

echo "[validate_prometheus] Done."
