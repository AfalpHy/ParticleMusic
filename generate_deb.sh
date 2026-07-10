#!/bin/bash

# ---------- CONFIG ----------
BINARY_NAME="sylvakru"
APP_NAME="Sylvakru"
APP_VERSION="3.4.6"
MAINTAINER="AfalpHy"

BUNDLE_DIR="build/linux/x64/release/bundle"

EXECUTABLE="$BUNDLE_DIR/$BINARY_NAME"
DATA="$BUNDLE_DIR/data"
LIB="$BUNDLE_DIR/lib"

PACKAGE_DIR="build/deb_pkg"

ICON_FILE="assets/app_icon.png"
# -----------------------------

# Clean previous build
rm -rf "$PACKAGE_DIR"

# Create directories
mkdir -p "$PACKAGE_DIR/DEBIAN"

# App bundle location
mkdir -p "$PACKAGE_DIR/usr/lib/$BINARY_NAME"

# Launcher
mkdir -p "$PACKAGE_DIR/usr/bin"

# Desktop integration
mkdir -p "$PACKAGE_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$PACKAGE_DIR/usr/share/applications"

# Copy Flutter bundle
cp "$EXECUTABLE" "$PACKAGE_DIR/usr/lib/$BINARY_NAME/"
cp -r "$DATA" "$PACKAGE_DIR/usr/lib/$BINARY_NAME/"
cp -r "$LIB" "$PACKAGE_DIR/usr/lib/$BINARY_NAME/"

# Create launcher script
cat > "$PACKAGE_DIR/usr/bin/$BINARY_NAME" <<EOL
#!/bin/sh
exec /usr/lib/$BINARY_NAME/$BINARY_NAME "\$@"
EOL

chmod 755 "$PACKAGE_DIR/usr/bin/$BINARY_NAME"
chmod 755 "$PACKAGE_DIR/usr/lib/$BINARY_NAME/$BINARY_NAME"

# Runtime dependencies
DEPENDS="libc6 (>= 2.31), libstdc++6, libgtk-3-0, libayatana-appindicator3-1, libdbusmenu-gtk3-4, libmpv1 | libmpv2, libsecret-1-0"

# Control file
cat > "$PACKAGE_DIR/DEBIAN/control" <<EOL
Package: $BINARY_NAME
Version: $APP_VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: $DEPENDS
Maintainer: $MAINTAINER
Description: $BINARY_NAME Flutter Linux app
 A Flutter desktop application for Linux.
EOL

# Copy icon
cp "$ICON_FILE" \
"$PACKAGE_DIR/usr/share/icons/hicolor/128x128/apps/$BINARY_NAME.png"

# Desktop entry
cat > "$PACKAGE_DIR/usr/share/applications/$BINARY_NAME.desktop" <<EOL
[Desktop Entry]
Name=$APP_NAME
Exec=$BINARY_NAME
Icon=$BINARY_NAME
Type=Application
Categories=Utility;
StartupWMClass=com.afalphy.sylvakru
Terminal=false
EOL

# Build package
dpkg-deb --build --root-owner-group "$PACKAGE_DIR"

mv "${PACKAGE_DIR}.deb" \
"build/${BINARY_NAME}-${APP_VERSION}-linux-amd64.deb"

echo "Debian package created:"
echo "build/${BINARY_NAME}-${APP_VERSION}-linux-amd64.deb"