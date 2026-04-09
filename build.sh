#!/bin/sh
set -e

# get version tag or commit id
VERSION=$(git describe HEAD)

# set app version
agvtool new-version ${VERSION:1}

# build
xcodebuild -quiet -configuration Release -target CursorContainmentField

# clean dist
rm -rf dist && mkdir dist

# make dmg from app
hdiutil create -fs HFS+ -srcfolder build/Release/CursorContainmentField.app -volname CursorContainmentField dist/CursorContainmentField.dmg

# clean build
rm -r build
