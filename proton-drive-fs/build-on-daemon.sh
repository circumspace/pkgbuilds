#!/usr/bin/env bash
set -euo pipefail

# Build a single PKGBUILD on daemon via SSH in a podman container
# Usage: ./build-on-daemon.sh <pkgname> [pkgdir]

PKGNAME="${1:?Usage: $0 <pkgname> [pkgdir]}"
PKGDIR="${2:-$PWD}"
REMOTE_DIR="/tmp/pkbuilds-build"

cd "$PKGDIR"

echo "==> Uploading source to daemon..."
rsync -avz --delete \
  --exclude='.git' \
  --exclude='*.tar.zst' \
  --exclude='*.pkg.tar.zst' \
  --exclude='*.pkg.tar' \
  --exclude='.SRCINFO' \
  "${PKGDIR}/" \
  daemon:"${REMOTE_DIR}/${PKGNAME}/"

echo "==> Pulling archlinux:base-devel image..."
ssh daemon "podman pull archlinux:base-devel 2>&1" | tail -3

echo "==> Building ${PKGNAME} in podman container..."
ssh daemon <<'ENDSSH'
set -euo pipefail
PKGNAME="$1"
BUILD_DIR="$2"

podman run --rm \
  -v "${BUILD_DIR}:/work:z" \
  -w /work \
  --userns=host \
  --cap-add=ALL \
  archlinux:base-devel \
  bash -c '
    pacman -Syu --noconfirm 2>&1 | tail -5
    pacman -S --noconfirm --needed base-devel go git 2>&1 | tail -5
    cd "${PKGNAME}"
    makepkg -si --noconfirm --skippgpcheck 2>&1
  '
ENDSSH

echo "==> Building ${PKGNAME} in podman container... (fixing args)"

# Actually run it properly
ssh daemon bash -s - "${PKGNAME}" "${REMOTE_DIR}" <<'ENDSSH'
set -euo pipefail
PKGNAME="$1"
BUILD_DIR="$2"

podman run --rm \
  -v "${BUILD_DIR}/${PKGNAME}:/work:z" \
  -w /work \
  --userns=host \
  --cap-add=ALL \
  archlinux:base-devel \
  bash -c '
    pacman -Syu --noconfirm 2>&1 | tail -5
    pacman -S --noconfirm --needed base-devel go git --overwrite="*" 2>&1 | tail -5
    makepkg -si --noconfirm --skippgpcheck 2>&1
  '
ENDSSH

echo "==> Build complete!"
echo "==> Installing on local system..."
# Copy the built package back
rsync -avz daemon:"${REMOTE_DIR}/${PKGNAME}/*.pkg.tar.zst" "${PKGDIR}/"
echo "==> Done. Packages in: ${PKGDIR}/"
ls -lh "${PKGDIR}"/*.pkg.tar.zst 2>/dev/null || echo "No .pkg.tar.zst found"
