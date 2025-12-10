RabbitMQ 4.2 Cluster Pipeline (Ubuntu 24.04)
===========================================

This bundle helps you bring up a 3-node RabbitMQ 4.2 cluster with:

- RabbitMQ 4.2 from Team RabbitMQ repo
- Filebeat
- Prometheus node_exporter
- Prometheus metrics from RabbitMQ
- Quorum queues by default
- LDAP backend (configured in advanced_*.config)
- Federation, shovel, AMQP 1.0, etc.
- Auto-clustering via systemd

Requirements (local machine where you run the pipeline)
------------------------------------------------------

- bash
- ssh
- scp
- sshpass  (used for username/password auth)
- Network connectivity to your 3 nodes (Ubuntu 24.04)

Files of interest
-----------------

- run_pipeline.sh           -> main entry point
- inventory_dev.txt         -> sample inventory for Dev (3 IPs, one per line)
- inventory_qa.txt          -> sample inventory for QA
- inventory_prod.txt        -> sample inventory for Prod

- ssh_dev.yaml              -> SSH config for Dev
- ssh_qa.yaml               -> SSH config for QA
- ssh_prod.yaml             -> SSH config for Prod

Scripts pushed to remote nodes (in /opt/rmq):
--------------------------------------------

- scripts/install_rabbitmq.sh
- scripts/install_filebeat.sh
- scripts/install_node_exporter.sh
- scripts/rmq-auto-cluster.sh
- scripts/setup_cluster.sh
- scripts/enable_plugins.sh
- scripts/install_env_advanced_config.sh
- scripts/validate_prometheus.sh
- scripts/install_cli_tools.sh

Config files pushed to remote nodes:
------------------------------------

- config/advanced_dev.config
- config/advanced_qa.config
- config/advanced_prod.config
- config/rmq-auto-cluster.service      -> installed under /etc/systemd/system/

What the pipeline does
----------------------

For a chosen environment (dev|qa|prod), the pipeline will:

1. Read inventory_ENV.txt for IPs (one per line).
2. Read ssh_ENV.yaml for SSH username/password.
3. Determine the seed node Erlang name by connecting to the first host and reading its hostname.
4. For each host:
   - Create /opt/rmq and upload all scripts + config files.
   - Generate /opt/rmq/env.sh with:
       - RABBITMQ_ERLANG_COOKIE
       - RABBITMQ_CLUSTER_NAME
       - RABBITMQ_ENV (Dev|QA|Prod)
       - RABBITMQ_SEED_NODE (derived from first host's hostname)
       - RABBITMQ_PROM_PORT
       - NODE_EXPORTER_PORT
   - Install RabbitMQ, Filebeat, node_exporter.
   - Install advanced_*.config based on environment.
   - Enable plugins, CLI tools.
   - Install rmq-auto-cluster.service and enable it.
   - Trigger a one-shot cluster setup (setup_cluster.sh).

Usage
-----

1. Edit the inventory_*.txt files to put your real IPs.
2. Edit ssh_*.yaml with your real username and password.
3. Optionally tweak config/advanced_*.config and scripts/install_* as desired.
4. From this directory:

   DEV:
     ./run_pipeline.sh dev

   QA:
     ./run_pipeline.sh qa

   PROD:
     ./run_pipeline.sh prod

You can safely run the pipeline multiple times; scripts are idempotent best-effort.
