#!/usr/bin/env bash
set -euo pipefail

if [ -f /opt/rmq/env.sh ]; then
  # shellcheck disable=SC1091
  source /opt/rmq/env.sh
else
  echo "[rmq-auto-cluster] /opt/rmq/env.sh not found; aborting."
  exit 1
fi

SEED="${RABBITMQ_SEED_NODE:-}"
COOKIE="${RABBITMQ_ERLANG_COOKIE:-}"

if [ -z "${SEED}" ] || [ -z "${COOKIE}" ]; then
  echo "[rmq-auto-cluster] RABBITMQ_SEED_NODE or RABBITMQ_ERLANG_COOKIE not set; aborting."
  exit 1
fi

echo "[rmq-auto-cluster] Starting on $(hostname) with seed ${SEED} ..."

sudo systemctl start rabbitmq-server

echo "${COOKIE}" | sudo tee /var/lib/rabbitmq/.erlang.cookie >/dev/null
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie

NODE_NAME="$(sudo rabbitmqctl eval 'node().' | tr -d '\r\n')"
echo "[rmq-auto-cluster] This node name: ${NODE_NAME}"

if ! sudo rabbitmqctl status >/dev/null 2>&1; then
  echo "[rmq-auto-cluster] rabbitmqctl status failed; aborting cluster join."
  exit 1
fi

CLUSTER_STATUS="$(sudo rabbitmqctl cluster_status || true)"

if echo "${CLUSTER_STATUS}" | grep -q "${NODE_NAME}"; then
  echo "[rmq-auto-cluster] Node ${NODE_NAME} already part of a cluster; no action needed."
  exit 0
fi

if [ "${NODE_NAME}" = "${SEED}" ]; then
  echo "[rmq-auto-cluster] This is the seed node; ensuring app is running."
  sudo rabbitmqctl start_app || true
  sudo rabbitmqctl cluster_status || true
  exit 0
fi

echo "[rmq-auto-cluster] Node not yet in cluster; attempting to join ${SEED} ..."
sudo rabbitmqctl stop_app || true

if ! echo "${CLUSTER_STATUS}" | grep -q "running_nodes"; then
  echo "[rmq-auto-cluster] No running_nodes found; safe to reset."
  sudo rabbitmqctl reset
else
  echo "[rmq-auto-cluster] running_nodes found; NOT resetting to avoid data loss."
fi

sudo rabbitmqctl join_cluster "${SEED}" || {
  echo "[rmq-auto-cluster] join_cluster failed; attempting to start app anyway."
}
sudo rabbitmqctl start_app || true

echo "[rmq-auto-cluster] Final cluster_status:"
sudo rabbitmqctl cluster_status || true

echo "[rmq-auto-cluster] Done."
