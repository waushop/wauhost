#!/bin/bash

# Set GitHub repo details
GITHUB_USER="your-username"
GITHUB_REPO="your-repo"
GITHUB_BRANCH="main"

# Ensure GITHUB_TOKEN is set
if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "❌ ERROR: GITHUB_TOKEN is not set!"
  exit 1
fi

# Install ghcp if not present
if ! command -v ghcp &> /dev/null; then
  echo "Installing ghcp..."
  go install github.com/int128/ghcp@latest
  export PATH=$HOME/go/bin:$PATH
fi

# Push the infra-repo to GitHub
ghcp commit --user "$GITHUB_USER" --repo "$GITHUB_REPO" --branch "$GITHUB_BRANCH" --message "Auto-update infra" ./infra-repo

echo "✅ Successfully pushed to GitHub!"