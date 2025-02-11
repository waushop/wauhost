#!/bin/bash

echo "🚀 Installing Helm charts..."

helm upgrade --install mysql charts/mysql -f values/mysql.yaml
helm upgrade --install ingress charts/ingress -f values/ingress.yaml
helm upgrade --install ghost charts/ghost -f values/ghost.yaml

echo "✅ Deployment complete!"