#!/usr/bin/env bash
set -euo pipefail

if [ -f /opt/rmq/env.sh ]; then
  # shellcheck disable=SC1091
  source /opt/rmq/env.sh
fi

echo "[setup_cluster] Manually triggering rmq-auto-cluster.sh on $(hostname)..."

if [ ! -x /opt/rmq/scripts/rmq-auto-cluster.sh ] && [ ! -x /usr/local/sbin/rmq-auto-cluster.sh ]; then
  echo "[setup_cluster] ERROR: rmq-auto-cluster.sh not found."
  exit 1
fi

if [ -x /opt/rmq/scripts/rmq-auto-cluster.sh ]; then
  sudo /opt/rmq/scripts/rmq-auto-cluster.sh
else
  sudo /usr/local/sbin/rmq-auto-cluster.sh
fi

echo "[setup_cluster] Cluster status after auto-cluster:"
sudo rabbitmqctl cluster_status
