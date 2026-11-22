#!/usr/bin/env bash
# Build proton-pass-biometrics on the "daemon" ssh host and fetch the package
# back. Keeps the heavy pnpm/cargo/webpack work off the laptop.
#
# Usage: ./build-on-daemon.sh [makepkg args...]
# Result: *.pkg.tar.zst in this directory; install with
#   sudo pacman -U proton-pass-biometrics-<ver>-<rel>-x86_64.pkg.tar.zst
set -euo pipefail

REMOTE=daemon
REMOTE_DIR=builds/proton-pass-biometrics
# Upstream engines require node ^24.22.1; node >=25 hangs inside
# electron-forge's zip extraction. corepack ships in the node 24 tarball.
NODE=24.22.3
RUST=1.99.0

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"

files=(PKGBUILD proton-pass.desktop ch.proton.pass.unlock.policy
       0001-rust-linux-biometrics-backend.patch
       0002-ts-enable-linux-biometrics.patch)
pkgver="$(sed -n 's/^pkgver=//p' PKGBUILD | head -1)"
tarball="proton-pass-biometrics-${pkgver}.tar.gz"
[[ -e $tarball ]] && files+=("$tarball")

ssh "$REMOTE" "mkdir -p $REMOTE_DIR && cd $REMOTE_DIR && rm -f proton-pass-biometrics-*.tar.gz"
rsync -av --checksum "${files[@]}" "$REMOTE:$REMOTE_DIR/"

makepkg_args=("$@")
if [[ ${#makepkg_args[@]} -eq 0 ]]; then
    # --nodeps: makedepends (nodejs-lts-krypton/corepack/rust) stay
    # unmaintained on the daemon; mise provides node+corepack+rust instead.
    makepkg_args=(-f --nodeps)
fi

# Patches are not idempotent: makepkg re-runs prepare() over an existing
# src/ tree on reruns, so always build from a fresh extraction.
# PATH must put the mise Node 24 bin before /usr/bin: pnpm and electron-forge
# re-resolve `node` from PATH (mise exec alone does not guarantee ordering,
# and Node >=25 silently breaks electron-forge packaging).
ssh "$REMOTE" "cd $REMOTE_DIR && rm -rf src pkg && \
    mise x node@$NODE rust@$RUST -- bash -c 'export PATH=\$HOME/.local/share/mise/installs/node/$NODE/bin:\$PATH && makepkg ${makepkg_args[*]}'"

rsync -av --include='*.pkg.tar.zst' --exclude='*' "$REMOTE:$REMOTE_DIR/" ./
echo
pkgfile="proton-pass-biometrics-$(sed -n 's/^pkgver=//p' PKGBUILD | head -1)-1-x86_64.pkg.tar.zst"
echo "Done. Install with:"
echo "  sudo pacman -U $pkgfile"
