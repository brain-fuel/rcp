#!/usr/bin/env bash
set -euo pipefail

echo "[install_cli_tools] Ensuring rabbitmqadmin and rabbitmqctl are usable..."

sudo apt-get update -y
sudo apt-get install -y python3 python3-urllib3

echo "[install_cli_tools] Downloading rabbitmqadmin from local management endpoint..."
curl -s -o rabbitmqadmin "http://localhost:15672/cli/rabbitmqadmin" || {
  echo "[install_cli_tools] Failed to download rabbitmqadmin"
  exit 1
}

sudo mv rabbitmqadmin /usr/local/bin/
sudo chmod +x /usr/local/bin/rabbitmqadmin

echo "[install_cli_tools] rabbitmqadmin version:"
rabbitmqadmin --version || true

echo "[install_cli_tools] rabbitmqctl status:"
sudo rabbitmqctl status | head -20 || true

echo "[install_cli_tools] Done."
