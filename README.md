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

## Review Process

### Steps for Reviewing Code Changes

1. **Pull the latest changes**: Ensure your local repository is up-to-date with the latest changes from the main branch.
2. **Create a new branch**: Create a new branch for your code changes.
3. **Make your changes**: Implement your changes and ensure they follow the project's coding standards.
4. **Run tests**: Run all tests to ensure your changes do not break existing functionality.
5. **Commit your changes**: Commit your changes with a clear and descriptive commit message.
6. **Push your changes**: Push your changes to the remote repository.

### Guidelines for Submitting Pull Requests

1. **Title and Description**: Provide a clear and concise title and description for your pull request.
2. **Link to Issue**: If applicable, link to the issue that your pull request addresses.
3. **Reviewers**: Add reviewers to your pull request.
4. **Labels**: Add appropriate labels to your pull request.
5. **Resolve Conflicts**: Ensure there are no merge conflicts with the main branch.
6. **Wait for Approval**: Wait for at least one approval from a reviewer before merging your pull request.
