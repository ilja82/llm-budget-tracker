#!/bin/bash
set -euo pipefail

# Read the current (released) version from project.yml
VERSION=$(grep 'MARKETING_VERSION:' project.yml | sed "s/.*MARKETING_VERSION: \"//;s/\".*//")
TAG="v$VERSION"

echo "WARNING: Only use this script if the DMG was never published."
echo "If users have already downloaded the release, do NOT revert — release a new patch instead."
echo ""
echo "About to revert release $TAG:"
echo "  - Delete remote tag $TAG"
echo "  - Delete local tag $TAG"
echo "  - Revert the release commit on main"
echo ""
read -r -p "Continue? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# Safety check: HEAD must be the release commit for this version
EXPECTED_MSG="Release $TAG"
ACTUAL_MSG=$(git log -1 --pretty=%s)
if [ "$ACTUAL_MSG" != "$EXPECTED_MSG" ]; then
  echo "Error: HEAD commit message is '$ACTUAL_MSG', expected '$EXPECTED_MSG'"
  echo "The release commit is not at HEAD — aborting to avoid reverting the wrong commit."
  exit 1
fi

echo "Deleting remote tag $TAG..."
git push origin --delete "$TAG"

echo "Deleting local tag $TAG..."
git tag -d "$TAG"

echo "Removing release commit from history..."
git reset --hard HEAD~1

echo "Force pushing to main..."
git push origin main --force

echo "Done. $TAG has been reverted. Fix the issue and run ./scripts/release.sh $VERSION again."
