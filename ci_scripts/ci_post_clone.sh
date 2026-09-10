#!/bin/sh
set -euo pipefail

# Xcode Cloud runs this after cloning the repo, before resolving packages / building.
# Keep GitHub Actions TestFlight (fastlane) unchanged — this path is Xcode Cloud only.

echo "ci_post_clone: T2Do — Xcode Cloud bootstrap"

# fastlane / Ruby gems are only needed for the GitHub Actions TestFlight lane.
# Xcode Cloud builds & tests via xcodebuild and does not need bundle install.

# Ensure the default scheme is resolvable (workspace-less .xcodeproj).
if [ ! -f "TwoDo.xcodeproj/project.pbxproj" ]; then
  echo "error: TwoDo.xcodeproj missing after clone" >&2
  exit 1
fi

echo "ci_post_clone: ok"
