#!/bin/bash
set -euo pipefail

if [ $# -eq 0 ]; then
  CURRENT=$(grep 'MARKETING_VERSION:' project.yml | sed "s/.*MARKETING_VERSION: \"//;s/\".*//")
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"
  PATCH=$((PATCH + 1))
  VERSION="$MAJOR.$MINOR.$PATCH"
else
  VERSION="$1"
fi
TAG="v$VERSION"

# Validate semver format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: version must be X.Y.Z (e.g. 1.2.3)"
  exit 1
fi

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

# Tag must not already exist
if git tag -l | grep -q "^${TAG}$"; then
  echo "Error: tag $TAG already exists locally"
  exit 1
fi
if git ls-remote --tags origin | grep -q "refs/tags/${TAG}$"; then
  echo "Error: tag $TAG already exists on origin"
  exit 1
fi

echo "Preparing release $TAG..."

# Bump MARKETING_VERSION in project.yml
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml

# Bump CURRENT_PROJECT_VERSION in project.yml
CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | sed "s/.*CURRENT_PROJECT_VERSION: \"//;s/\".*//")
NEXT_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: \"[^\"]*\"/CURRENT_PROJECT_VERSION: \"$NEXT_BUILD\"/" project.yml

git add project.yml
git commit -m "Release $TAG"
git push origin main

git tag "$TAG"
git push origin "$TAG"

echo "Done. GitHub Actions will now build and publish the $TAG release."
