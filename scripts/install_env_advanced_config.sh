#!/usr/bin/env bash
set -euo pipefail
[ -f /opt/rmq/env.sh ] && source /opt/rmq/env.sh

SRC_DIR="/opt/rmq/config"
DEST="/etc/rabbitmq/advanced.config"

case "${RABBITMQ_ENV}" in
  Dev|dev)   FILE="${SRC_DIR}/advanced_dev.config" ;;
  QA|qa)     FILE="${SRC_DIR}/advanced_qa.config" ;;
  Prod|prod) FILE="${SRC_DIR}/advanced_prod.config" ;;
  *) echo "[install_env_advanced_config] Unknown environment: ${RABBITMQ_ENV}" ; exit 1 ;;
esac

echo "[install_env_advanced_config] Installing ${FILE} -> ${DEST}"
sudo mkdir -p /etc/rabbitmq
sudo cp "${FILE}" "${DEST}"
sudo chown rabbitmq:rabbitmq "${DEST}" || true

sudo systemctl restart rabbitmq-server
echo "[install_env_advanced_config] Done for env ${RABBITMQ_ENV}."
