#!/usr/bin/env bash
# Build signed metadata for a flat APT repository hosted as release assets.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'Usage: %s PACKAGE_DEB OUTPUT_DIR SIGNING_KEY_FINGERPRINT\n' "$0" >&2
    exit 2
fi

deb=$(realpath "$1")
out=$(realpath -m "$2")
fingerprint=$3
[[ -f $deb ]] || { printf 'Package not found: %s\n' "$deb" >&2; exit 1; }
[[ $fingerprint =~ ^[A-F0-9]{40}$ ]] || {
    printf 'Expected a full uppercase OpenPGP fingerprint\n' >&2
    exit 1
}

install -d "$out"
cp "$deb" "$out/"

(
    cd "$out"
    apt-ftparchive packages . > Packages
    gzip -9n -c Packages > Packages.gz
    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin='Zen Browser Personal' \
        -o APT::FTPArchive::Release::Label='Zen Browser Personal' \
        -o APT::FTPArchive::Release::Suite='stable' \
        -o APT::FTPArchive::Release::Codename='stable' \
        -o APT::FTPArchive::Release::Architectures='amd64' \
        -o APT::FTPArchive::Release::Components='main' \
        release . > Release
)

gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --local-user "$fingerprint" --clearsign \
    --output "$out/InRelease" "$out/Release"
gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --local-user "$fingerprint" --armor --detach-sign \
    --output "$out/Release.gpg" "$out/Release"
gpg --batch --verify "$out/InRelease" >/dev/null
printf 'Signed flat APT repository written to %s\n' "$out"
