#!/usr/bin/env bash
set -euo pipefail
[ -f /opt/rmq/env.sh ] && source /opt/rmq/env.sh

SRC_DIR="/opt/rmq/config"
ETC_DIR="/etc/rabbitmq"

echo "[install_rabbitmq_configs] Using RABBITMQ_ENV=${RABBITMQ_ENV}"

# 1) Decide which advanced.config to use based on environment
case "${RABBITMQ_ENV}" in
  Dev|dev|Dev2|dev2)   ADV_FILE="${SRC_DIR}/advanced_dev.config" ;;
  QA|qa|QA2|qa2|QA_EAST2|qa_east2|QA_WEST2|qa_west2)     ADV_FILE="${SRC_DIR}/advanced_qa.config" ;;
  Prod|prod|Prod2|prod2|PROD_EAST2|prod_east2|PROD_WEST2|prod_west2) ADV_FILE="${SRC_DIR}/advanced_prod.config" ;;
  *)
    echo "[install_rabbitmq_configs] Unknown RABBITMQ_ENV='${RABBITMQ_ENV}'"
    exit 1
    ;;
esac

# 2) Ensure /etc/rabbitmq exists
sudo mkdir -p "${ETC_DIR}"

# 3) Install advanced.config
echo "[install_rabbitmq_configs] Installing ${ADV_FILE} -> ${ETC_DIR}/advanced.config"
sudo cp "${ADV_FILE}" "${ETC_DIR}/advanced.config"
sudo chown rabbitmq:rabbitmq "${ETC_DIR}/advanced.config" || true

# 4) Install rabbitmq-env.conf (same for all envs)
ENV_CONF_SRC="${SRC_DIR}/rabbitmq-env.conf"
ENV_CONF_DEST="${ETC_DIR}/rabbitmq-env.conf"

echo "[install_rabbitmq_configs] Installing ${ENV_CONF_SRC} -> ${ENV_CONF_DEST}"
sudo cp "${ENV_CONF_SRC}" "${ENV_CONF_DEST}"
sudo chown root:rabbitmq "${ENV_CONF_DEST}" || true
sudo chmod 640 "${ENV_CONF_DEST}" || true

# 5) Generate rabbitmq.conf from template and env vars
CONF_TEMPLATE="${SRC_DIR}/rabbitmq.conf.template"
CONF_DEST="${ETC_DIR}/rabbitmq.conf"

PROM_PORT="${RABBITMQ_PROM_PORT:-15692}"
CLUSTER_NAME="${RABBITMQ_CLUSTER_NAME:-rmq-cluster}"

echo "[install_rabbitmq_configs] Rendering rabbitmq.conf from template..."
sudo bash -c "sed \
  -e 's/@@PROM_PORT@@/${PROM_PORT}/g' \
  -e 's/@@CLUSTER_NAME@@/${CLUSTER_NAME}/g' \
  '${CONF_TEMPLATE}' > '${CONF_DEST}'"

sudo chown root:rabbitmq "${CONF_DEST}" || true
sudo chmod 640 "${CONF_DEST}" || true

echo "[install_rabbitmq_configs] Restarting rabbitmq-server to pick up config..."
sudo systemctl restart rabbitmq-server

echo "[install_rabbitmq_configs] Done for env ${RABBITMQ_ENV}."
