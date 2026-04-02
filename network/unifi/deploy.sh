#!/bin/bash
set -e

echo "Deploying UniFi controller..."

kubectl apply -f core/
kubectl apply -f routing/

echo "Done. Maintenance jobs in maintenance/ can be applied manually when needed."
