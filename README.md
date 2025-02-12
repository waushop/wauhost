# 🚀 Kubernetes Infrastructure Repository (Fixed Version)

This repository contains Helm charts for deploying Ghost, MySQL, and Ingress with Let's Encrypt SSL.

## 📁 Project Structure
```
wauhost_fixed/
│── charts/                 # Helm charts
│   ├── ingress/            # Ingress Controller Helm chart
│   ├── cert-manager/       # Cert-Manager for automatic SSL
│   ├── mysql/              # MySQL Helm chart
│   ├── ghost/              # Ghost Helm chart
│── values/                 # Config files for Helm charts
│── deployments/            # Deployment-specific configurations
│── .github/workflows/      # GitHub Actions for CI/CD
│── install.sh              # Helm install script
│── upload.sh               # Auto-push to GitHub script
│── README.md               # Documentation
```

## 🔧 Deployment Steps

### 1️⃣ Install Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 2️⃣ Deploy Services
```bash
./install.sh
```

### 3️⃣ Push to GitHub (Optional)
```bash
./upload.sh
```

## 🚀 Features
✅ **Centralized Global Configuration (`values/global.yaml`)**  
✅ **Ingress with SSL (Traefik/Nginx)**  
✅ **Ghost Blog Deployment**  
✅ **MySQL Backend with Persistent Storage**  
✅ **GitHub Auto-Deploy Support**  

---
