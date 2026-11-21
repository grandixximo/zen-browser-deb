#!/usr/bin/env bash
# Repackage an official Zen Browser Linux tar.xz as a native Debian package.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'Usage: %s UPSTREAM_VERSION ZEN_TAR_XZ OUTPUT_DIR\n' "$0" >&2
    exit 2
fi

version=${1#v}
tarball=$(realpath "$2")
out=$(realpath -m "$3")

[[ $version =~ ^[0-9][A-Za-z0-9.+~:-]*$ ]] || {
    printf 'Unsafe Debian version: %s\n' "$version" >&2
    exit 1
}
[[ -f $tarball ]] || { printf 'Tarball not found: %s\n' "$tarball" >&2; exit 1; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(dirname "$script_dir")
work=$(mktemp -d "${TMPDIR:-/tmp}/zen-browser-deb.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

install -d "$work/extract" "$out"
tar -xJf "$tarball" -C "$work/extract"
[[ -d $work/extract/zen ]] || {
    printf 'Unexpected archive layout: missing top-level zen directory\n' >&2
    exit 1
}
[[ -x $work/extract/zen/zen && -f $work/extract/zen/libxul.so ]] || {
    printf 'Archive does not contain the expected Zen binaries\n' >&2
    exit 1
}

root=$work/root
install -d "$root/opt" "$root/usr/bin" "$root/usr/share/applications"
cp -a "$work/extract/zen" "$root/opt/zen"

# Firefox enterprise policy disables the self-updater. APT owns updates.
install -D -m 644 "$project_dir/packaging/policies.json" \
    "$root/opt/zen/distribution/policies.json"
install -m 644 "$project_dir/packaging/zen.desktop" \
    "$root/usr/share/applications/zen.desktop"

printf '%s\n' '#!/bin/sh' 'exec /opt/zen/zen "$@"' > "$root/usr/bin/zen"
chmod 755 "$root/usr/bin/zen"

icon_count=0
for size in 16 32 48 64 128 256; do
    icon="$root/opt/zen/browser/chrome/icons/default/default${size}.png"
    if [[ -f $icon ]]; then
        install -D -m 644 "$icon" \
            "$root/usr/share/icons/hicolor/${size}x${size}/apps/zen.png"
        icon_count=$((icon_count + 1))
    fi
done
(( icon_count > 0 )) || { printf 'No Zen application icons found\n' >&2; exit 1; }

installed_size=$(du -sk "$root" | cut -f1)
install -d "$root/DEBIAN"
cat > "$root/DEBIAN/control" <<EOF
Package: zen-browser
Version: ${version}-1
Section: web
Priority: optional
Architecture: amd64
Installed-Size: ${installed_size}
Depends: libasound2t64, libatk-bridge2.0-0t64, libatk1.0-0t64, libc6, libcairo2, libcups2t64, libdbus-1-3, libdbus-glib-1-2, libdrm2, libfontconfig1, libfreetype6, libgbm1, libgcc-s1, libgdk-pixbuf-2.0-0, libglib2.0-0t64, libgtk-3-0t64, libnspr4, libnss3, libpango-1.0-0, libpulse0, libstdc++6, libx11-6, libx11-xcb1, libxcb-shm0, libxcb1, libxcomposite1, libxcursor1, libxdamage1, libxext6, libxfixes3, libxi6, libxkbcommon0, libxrandr2, libxrender1, libxshmfence1, libxt6
Provides: www-browser
Maintainer: grandixximo <toniolo.luca@gmail.com>
Homepage: https://zen-browser.app/
Description: Zen Browser native binaries packaged for Debian
 Zen is a Firefox-based browser focused on workspaces and a compact UI.
 This package repackages the official upstream Linux x86-64 binaries.
EOF

package="zen-browser_${version}-1_amd64.deb"
dpkg-deb --root-owner-group -Zxz -z9 --build "$root" "$out/$package"
dpkg-deb --info "$out/$package" >/dev/null
printf '%s\n' "$out/$package"
