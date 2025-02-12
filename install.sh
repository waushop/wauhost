#!/bin/bash

echo "🚀 Installing Helm charts..."

helm upgrade --install secrets charts/secrets -f values/global.yaml
helm upgrade --install mysql charts/mysql -f values/global.yaml -f values/mysql.yaml
helm upgrade --install ingress charts/ingress -f values/global.yaml -f values/ingress.yaml
helm upgrade --install ghost charts/ghost -f values/global.yaml -f values/ghost.yaml

echo "✅ Deployment complete!"
