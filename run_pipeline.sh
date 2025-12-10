#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 {dev|qa|prod}"
  exit 1
fi

ENV="$1"
case "${ENV}" in
  dev|qa|prod) ;;
  *) echo "Environment must be dev, qa, or prod"; exit 1 ;;
esac

INVENTORY_FILE="inventory_${ENV}.txt"
SSH_CONFIG="ssh_${ENV}.yaml"

if [ ! -f "${INVENTORY_FILE}" ]; then
  echo "Inventory file ${INVENTORY_FILE} not found"
  exit 1
fi

if [ ! -f "${SSH_CONFIG}" ]; then
  echo "SSH config ${SSH_CONFIG} not found"
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "sshpass not found; please install it (e.g., sudo apt-get install -y sshpass)"
  exit 1
fi

USER=$(grep -E 'user:' "${SSH_CONFIG}" | awk '{print $2}')
PASS=$(grep -E 'pas:'  "${SSH_CONFIG}" | awk '{print $2}' | tr -d '"')

if [ -z "${USER}" ] || [ -z "${PASS}" ]; then
  echo "Failed to parse user or pas from ${SSH_CONFIG}"
  exit 1
fi

# cookie/cluster name defaults (you can change these)
RABBITMQ_ERLANG_COOKIE="SuperSecretCookieHere"
RABBITMQ_CLUSTER_NAME="rmq-cluster"
RABBITMQ_PROM_PORT="15692"
NODE_EXPORTER_PORT="9100"

HOSTS=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  HOSTS+=("$line")
done < "${INVENTORY_FILE}"

if [ ${#HOSTS[@]} -eq 0 ]; then
  echo "No hosts found in ${INVENTORY_FILE}"
  exit 1
fi

SEED_IP="${HOSTS[0]}"

echo "[run_pipeline] Determining seed node Erlang name from ${SEED_IP}..."
SEED_HOSTNAME=$(sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${SEED_IP}" "hostname -s")
RABBITMQ_SEED_NODE="rabbit@${SEED_HOSTNAME}"
echo "[run_pipeline] Seed Erlang node: ${RABBITMQ_SEED_NODE}"

# Push scripts and configs to each host and run installation
for IP in "${HOSTS[@]}"; do
  echo
  echo "========== Processing host ${IP} =========="

  # Create remote base dir
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "sudo mkdir -p /opt/rmq && sudo chown ${USER}:${USER} /opt/rmq"

  echo "[run_pipeline] Copying scripts and config to ${IP}..."
  sshpass -p "${PASS}" scp -o StrictHostKeyChecking=no -r scripts config "${USER}@${IP}":/opt/rmq/

  echo "[run_pipeline] Writing /opt/rmq/env.sh on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cat <<'EOF' | sudo tee /opt/rmq/env.sh >/dev/null
#!/usr/bin/env bash
export RABBITMQ_ERLANG_COOKIE=\"${RABBITMQ_ERLANG_COOKIE}\"
export RABBITMQ_CLUSTER_NAME=\"${RABBITMQ_CLUSTER_NAME}\"
export RABBITMQ_SEED_NODE=\"${RABBITMQ_SEED_NODE}\"
export RABBITMQ_ENV=\"${ENV^}\"
export RABBITMQ_PROM_PORT=\"${RABBITMQ_PROM_PORT}\"
export NODE_EXPORTER_PORT=\"${NODE_EXPORTER_PORT}\"
EOF
sudo chmod +x /opt/rmq/env.sh"

  echo "[run_pipeline] Making scripts executable on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && chmod +x scripts/*.sh"

  echo "[run_pipeline] Installing RabbitMQ on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/install_rabbitmq.sh"

  echo "[run_pipeline] Installing Filebeat on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/install_filebeat.sh"

  echo "[run_pipeline] Installing node_exporter on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/install_node_exporter.sh"

  echo "[run_pipeline] Installing environment-specific advanced.config on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/install_env_advanced_config.sh"

  echo "[run_pipeline] Enabling plugins on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/enable_plugins.sh"

  echo "[run_pipeline] Installing CLI tools (rabbitmqadmin, etc.) on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/install_cli_tools.sh"

  echo "[run_pipeline] Installing systemd auto-cluster unit on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && sudo cp config/rmq-auto-cluster.service /etc/systemd/system/rmq-auto-cluster.service && sudo systemctl daemon-reload && sudo systemctl enable rmq-auto-cluster.service"

  echo "[run_pipeline] Triggering one-off cluster setup on ${IP}..."
  sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no "${USER}@${IP}" "cd /opt/rmq && ./scripts/setup_cluster.sh"

  echo "========== Done with host ${IP} =========="
done

echo
echo "[run_pipeline] All hosts processed. You may want to run validate_prometheus.sh manually on one node:"
echo "  ssh ${USER}@${SEED_IP} 'cd /opt/rmq && ./scripts/validate_prometheus.sh'"
