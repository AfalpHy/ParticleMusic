#!/bin/bash

# ---------- CONFIG ----------
BINARY_NAME="sylvakru"
APP_NAME="Sylvakru"
APP_VERSION="3.4.6"
MAINTAINER="AfalpHy <736353503@qq.com>"

BUNDLE_DIR="build/linux/x64/release/bundle"

EXECUTABLE="$BUNDLE_DIR/$BINARY_NAME"
DATA="$BUNDLE_DIR/data"
LIB="$BUNDLE_DIR/lib"

PACKAGE_DIR="build/rpm_pkg"

ICON_FILE="assets/app_icon.png"
# -----------------------------

echo "=== Generating Native RPM Package ==="

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR/usr/lib/$BINARY_NAME"
mkdir -p "$PACKAGE_DIR/usr/bin"
mkdir -p "$PACKAGE_DIR/usr/share/icons/hicolor/128x128/apps"
mkdir -p "$PACKAGE_DIR/usr/share/applications"

cp "$EXECUTABLE" "$PACKAGE_DIR/usr/lib/$BINARY_NAME/"
cp -r "$DATA" "$PACKAGE_DIR/usr/lib/$BINARY_NAME/"
cp -r "$LIB" "$PACKAGE_DIR/usr/lib/$BINARY_NAME/"

cat > "$PACKAGE_DIR/usr/bin/$BINARY_NAME" <<EOL
#!/bin/sh
exec /usr/lib/$BINARY_NAME/$BINARY_NAME "\$@"
EOL

chmod 755 "$PACKAGE_DIR/usr/bin/$BINARY_NAME"
chmod 755 "$PACKAGE_DIR/usr/lib/$BINARY_NAME/$BINARY_NAME"

cp "$ICON_FILE" "$PACKAGE_DIR/usr/share/icons/hicolor/128x128/apps/$BINARY_NAME.png"

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

DEPENDS="glibc >= 2.31, libstdc++, gtk3, libayatana-appindicator3, libdbusmenu-gtk3, mpv-libs, libsecret"

SPEC_FILE="build/${BINARY_NAME}.spec"

cat > "$SPEC_FILE" <<EOL
Name:           $BINARY_NAME
Version:        $APP_VERSION
Release:        1
Summary:        $APP_NAME Desktop Application
License:        Proprietary
URL:            https://github.com/AfalpHy/sylvakru
BuildArch:      x86_64

Requires:       $DEPENDS

AutoReqProv:    no

%description
A private music oasis in the digital world.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}

cp -r $PWD/$PACKAGE_DIR/usr %{buildroot}/

%files

/usr/bin/$BINARY_NAME
/usr/lib/$BINARY_NAME/
/usr/share/icons/hicolor/128x128/apps/$BINARY_NAME.png
/usr/share/applications/$BINARY_NAME.desktop

EOL

rpmbuild -bb "$SPEC_FILE" \
  --define "_rpmdir $PWD/build" \
  --nodeps

mv build/x86_64/*.rpm build/ 2>/dev/null
rm -rf build/x86_64

echo "------------------------------------------------"
echo "Native RPM package created successfully:"
echo "build/${BINARY_NAME}-${APP_VERSION}-1.x86_64.rpm"
echo "------------------------------------------------"