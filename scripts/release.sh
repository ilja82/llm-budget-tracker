#!/bin/bash
set -euo pipefail

# Must be on main
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "Error: must be on main branch (currently on '$BRANCH')"
  exit 1
fi

# No uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working directory has uncommitted changes"
  exit 1
fi

# In sync with origin/main
git fetch origin main --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
if [ "$LOCAL" != "$REMOTE" ]; then
  echo "Error: local main is not in sync with origin/main (run 'git pull')"
  exit 1
fi

# Read version from project.yml
VERSION=$(grep 'MARKETING_VERSION:' project.yml | sed "s/.*MARKETING_VERSION: \"//;s/\".*//")
TAG="v$VERSION"

# Tag must not already exist
if git tag -l | grep -q "^${TAG}$"; then
  echo "Error: tag $TAG already exists locally"
  exit 1
fi
if git ls-remote --tags origin | grep -q "refs/tags/${TAG}$"; then
  echo "Error: tag $TAG already exists on origin"
  exit 1
fi

git tag "$TAG"
git push origin "$TAG"

echo "Done. GitHub Actions will now build and publish the $TAG release."
