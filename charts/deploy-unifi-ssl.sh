#!/bin/bash

# Unifi SSL Setup with Traefik
# This script deploys all necessary resources for SSL termination

set -e

echo "🚀 Starting Unifi SSL setup with Traefik..."

# Apply the service
echo "📡 Creating Unifi ingress service..."
kubectl apply -f unifi-ingress.yaml

# Apply middleware
echo "🔧 Creating Traefik middleware..."
kubectl apply -f unifi-middleware.yaml

# Apply transport and TLS options
echo "🔐 Creating SSL transport and TLS options..."
kubectl apply -f unifi-transport.yaml

# Apply HTTP route (for testing)
echo "🌐 Creating HTTP route..."
kubectl apply -f unifi-web-route.yaml

# Apply HTTPS route
echo "🔒 Creating HTTPS route with SSL..."
kubectl apply -f unifi-secure-route.yaml

# Apply TCP routes for controller communication
echo "🔌 Creating TCP routes for controller communication..."
kubectl apply -f unifi-tcp-routes.yaml

# Wait for resources to be ready
echo "⏳ Waiting for resources to be ready..."
sleep 10

# Check status
echo "✅ Checking resource status..."
kubectl get ingressroute -n unifi
kubectl get middleware -n unifi
kubectl get serverstransport -n unifi
kubectl get service -n unifi

echo ""
echo "🎉 Unifi SSL setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Test with: curl -I https://unifi.waushop.ee"
echo "2. Check certificate: kubectl get secret unifi-tls -n unifi"
echo "3. Monitor Traefik dashboard for routing"
echo "4. Once verified, you can remove the old LoadBalancer services:"
echo "   kubectl delete svc unifi-service unifi-443 -n unifi"
echo ""
echo "🔍 Troubleshooting:"
echo "- Check Traefik logs: kubectl logs -n kube-system -l app.kubernetes.io/name=traefik"
echo "- Check certificate: kubectl describe certificate -n unifi"
echo "- Test routing: kubectl get ingressroute -n unifi -o yaml"