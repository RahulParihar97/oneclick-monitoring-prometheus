#!/bin/bash

set -e

echo
echo "=========================================="
echo "Fetching Terraform Outputs..."
echo "=========================================="

BASTION=$(terraform -chdir=terraform output -raw bastion_public_ip)
MONITOR=$(terraform -chdir=terraform output -raw monitoring_private_ip)

echo
echo "Bastion IP   : $BASTION"
echo "Monitoring IP: $MONITOR"

echo
echo "=========================================="
echo "Opening SSH Tunnel..."
echo "=========================================="
echo
echo "Prometheus : http://localhost:9090"
echo "Grafana    : http://localhost:3000"
echo
echo "Keep this terminal open."
echo "Press Ctrl+C to close the tunnel."
echo

ssh \
    -i ansible/ansible-demo.pem \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=60 \
    -N \
    -L 9090:${MONITOR}:9090 \
    -L 3000:${MONITOR}:3000 \
    ubuntu@${BASTION}
