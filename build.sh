#!/bin/sh
set -e

# Build version from the latest tag (e.g. v2.1.0 -> 2.1.0) if there is one;
# otherwise keep the version set in the project.
TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
VERSION_ARGS=""
if [ -n "$TAG" ]; then
  VERSION_ARGS="CURRENT_PROJECT_VERSION=${TAG#v} MARKETING_VERSION=${TAG#v}"
fi

# build
xcodebuild -quiet \
  -project CursorContainmentField.xcodeproj \
  -scheme CursorContainmentField \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  $VERSION_ARGS \
  build

# clean dist
rm -rf dist && mkdir dist

# make dmg from app
hdiutil create -fs HFS+ -srcfolder build/DerivedData/Build/Products/Release/CursorContainmentField.app -volname CursorContainmentField dist/CursorContainmentField.dmg

# clean build
rm -r build
