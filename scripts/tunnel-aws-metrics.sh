#!/usr/bin/env bash
# SSH multiplex forwards — key optional if ssh-agent works.
set -euo pipefail

HOST="${AWS_SSH_HOST:?export AWS_SSH_HOST (EC2 hostname or IP)}"
USER="${AWS_SSH_USER:-ec2-user}"

SSH_ARGS=(ssh -N -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes)
SSH_ARGS+=(-L "19101:127.0.0.1:9101" -L "19102:127.0.0.1:9102" -L "19103:127.0.0.1:9103" -L "19104:127.0.0.1:9104" -L "19105:127.0.0.1:9105")

if [[ -n "${AWS_SSH_KEY:-}" ]]; then
  KEY_EXPAND="${AWS_SSH_KEY/#\~/$HOME}"
  SSH_ARGS+=(-i "$KEY_EXPAND")
fi

SSH_ARGS+=("$USER@$HOST")

echo "Forwarding local 19101→9101 (mdp) … 19105→9105 (order_executor)"
echo "Then run: cd hmm-mdp-grafana && docker compose up -d"

exec "${SSH_ARGS[@]}"
