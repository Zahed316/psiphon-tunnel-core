#!/usr/bin/env bash
set -euo pipefail

# Build a Linux amd64 .deb package for the Psiphon client library.
# Run from repository root:
#   ./ClientLibrary/build-linux-amd64-deb.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/ClientLibrary/build/linux/amd64"

REV="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"
DATE="$(date +%Y%m%d)"
VERSION="1.0.11+${DATE}.git${REV}"
PKG_NAME="psiphon-client-lib"
PKGROOT="/tmp/${PKG_NAME}-amd64"
OUT_DEB="$ROOT_DIR/${PKG_NAME}_${VERSION}_amd64.deb"

mkdir -p "$BUILD_DIR"

pushd "$ROOT_DIR/ClientLibrary" >/dev/null
GOOS=linux GOARCH=amd64 go build -buildmode=c-shared -o "$BUILD_DIR/libpsiphontunnel.so" PsiphonTunnel.go
popd >/dev/null

rm -rf "$PKGROOT"
mkdir -p "$PKGROOT/DEBIAN" "$PKGROOT/usr/lib" "$PKGROOT/usr/include" "$PKGROOT/usr/share/doc/${PKG_NAME}"

cp "$BUILD_DIR/libpsiphontunnel.so" "$PKGROOT/usr/lib/"
cp "$BUILD_DIR/libpsiphontunnel.h" "$PKGROOT/usr/include/"

cat > "$PKGROOT/DEBIAN/control" <<CONTROL
Package: ${PKG_NAME}
Version: ${VERSION}
Section: libs
Priority: optional
Architecture: amd64
Maintainer: Psiphon Build Agent <noreply@example.com>
Depends: libc6
Description: Psiphon Tunnel Core client library (Linux amd64)
 C-shared client library and header for embedding Psiphon in Linux applications.
CONTROL

cat > "$PKGROOT/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
ldconfig || true
POSTINST
chmod 755 "$PKGROOT/DEBIAN/postinst"

cp "$ROOT_DIR/README.md" "$PKGROOT/usr/share/doc/${PKG_NAME}/README.upstream"
gzip -f -9 "$PKGROOT/usr/share/doc/${PKG_NAME}/README.upstream"

dpkg-deb --build "$PKGROOT" "$OUT_DEB"

echo "Built package: $OUT_DEB"
