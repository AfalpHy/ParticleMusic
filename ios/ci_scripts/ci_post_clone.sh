#!/bin/sh

set -e

FLUTTER_VERSION=3.44.5
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.44.5-stable.zip"

echo "Downloading Flutter $FLUTTER_VERSION..."

curl -L "$FLUTTER_URL" -o /tmp/flutter.zip

echo "Extracting Flutter..."

unzip -q /tmp/flutter.zip -d "$HOME"

export PATH="$HOME/flutter/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Precache iOS artifacts..."
flutter precache --ios

echo "Getting dependencies..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "Installing pods..."
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install