# Zen Browser native Debian package and APT repository

Unofficial personal packaging of [Zen Browser](https://zen-browser.app/) for **Debian 13 (trixie), amd64**. The workflow repackages the official upstream Linux binary; it does not compile Zen from source.

## Install

```bash
sudo install -d -m 0755 /usr/share/keyrings
curl -fsSL https://raw.githubusercontent.com/grandixximo/zen-browser-deb/main/zen-browser-deb.gpg \
    | sudo tee /usr/share/keyrings/zen-browser-deb.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/zen-browser-deb.gpg] https://github.com/grandixximo/zen-browser-deb/releases/download/apt ./' \
    | sudo tee /etc/apt/sources.list.d/zen-browser-deb.list
sudo apt-get update
sudo apt-get install zen-browser
```

After installation, updates arrive through normal `apt-get update && apt-get upgrade`.

## Archive signing key

- Identity: `Zen Browser Personal APT Archive <apt@grandixximo.github.io>`
- Fingerprint: `57CD F649 F0C3 6D83 327D CA34 44F4 4AB0 500F 9C3F`

APT metadata is signed with this key. The upstream tar is checked against the SHA-256 digest exposed by the official `zen-browser/desktop` GitHub release API.

## Automation

`.github/workflows/update.yml` checks upstream every six hours and on demand. For a new release it:

1. Downloads and verifies `zen.linux-x86_64.tar.xz`.
2. Repackages it as `zen-browser_<upstream>-1_amd64.deb`.
3. Installs and checks the package in a Debian 13 container.
4. Publishes the deb and signed flat-repository metadata as assets on the rolling `apt` release.
5. Records the packaged tag in `state/latest-release`.

The package disables Zen's built-in updater because APT owns application updates.

GitHub disables scheduled workflows after 60 days of repository inactivity. `.github/workflows/keepalive.yml` checks weekly and creates an empty commit only when the latest commit is at least 45 days old. No manual empty PRs are needed.

## Why release assets instead of GitHub Pages?

The current upstream tar is already larger than GitHub's 100 MB git-file limit, and the deb is similarly large. A flat APT repository backed by rolling-release assets avoids that limit while retaining signed `Release`, `InRelease`, and `Packages` metadata.

## Scope and affiliation

This is personal, unofficial packaging. Zen Browser is licensed separately; see upstream for its source code and license. Only Debian 13 amd64 is currently tested.
