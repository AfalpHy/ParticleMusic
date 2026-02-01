#!/bin/bash

# ---------- CONFIG ----------
APP_NAME="ParticleMusic"           # Executable name
APP_VERSION="1.0.10"               # Debian version
MAINTAINER="AfalpHy"
EXECUTABLE="build/linux/x64/release/bundle/$APP_NAME"
DATA="build/linux/x64/release/bundle/data"
LIB="build/linux/x64/release/bundle/lib"
PACKAGE_DIR="build/deb_pkg"
ICON_FILE="assets/app_icon.png"        # App icon
# -----------------------------

# Clean previous build
rm -rf $PACKAGE_DIR
mkdir -p $PACKAGE_DIR/DEBIAN
mkdir -p $PACKAGE_DIR/usr/local/bin
mkdir -p $PACKAGE_DIR/usr/share/icons/hicolor/128x128/apps
mkdir -p $PACKAGE_DIR/usr/share/applications

# Copy binary
cp "$EXECUTABLE" "$PACKAGE_DIR/usr/local/bin/$APP_NAME"
cp "$DATA" -r "$PACKAGE_DIR/usr/local/bin/"
cp "$LIB" -r "$PACKAGE_DIR/usr/local/bin/"

# Auto-detect dependencies
echo "Detecting dependencies..."
DEPENDS="libc6 (>= 2.31), libstdc++6, libgtk-3-0, libayatana-appindicator3-1, libdbusmenu-gtk3-4, libx11-6, libxext6, libxrender1, libwayland-client0, libwayland-cursor0, libwayland-egl1-mesa, libxkbcommon0, libopusfile0"
echo "Detected dependencies: $DEPENDS"

# Create control file
cat > "$PACKAGE_DIR/DEBIAN/control" <<EOL
Package: $APP_NAME
Version: $APP_VERSION
Section: base
Priority: optional
Architecture: amd64
Depends: $DEPENDS
Maintainer: $MAINTAINER
Description: $APP_NAME Flutter Linux app
 A Flutter desktop application for Linux.
EOL

# Copy icon
cp "$ICON_FILE" "$PACKAGE_DIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"

# Create desktop entry
cat > "$PACKAGE_DIR/usr/share/applications/$APP_NAME.desktop" <<EOL
[Desktop Entry]
Name=$APP_NAME
Exec=/usr/local/bin/$APP_NAME
Icon=$APP_NAME
Type=Application
Categories=Utility;
StartupWMClass=Com.afalphy.particle_music
EOL

# Build .deb
dpkg-deb --build "$PACKAGE_DIR"
mv "${PACKAGE_DIR}.deb" "build/${APP_NAME}-${APP_VERSION}-linux-amd64.deb"

echo "Debian package created: build/${APP_NAME}-${APP_VERSION}-linux-amd64.deb"
