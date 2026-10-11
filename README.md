# Unofficial Arch PKGBUILDs — Proton Pass Desktop

Source-built **Proton Pass Desktop** packages for Arch Linux:

| Directory | Arch | What it is |
|---|---|---|
| `proton-pass-aarch64/` | aarch64 | Proton Pass for **Arch Linux ARM** on system Electron, with the cookie sign-in fix |
| `electron39-bin/` | aarch64 | Electron 39.8.10 runtime for `proton-pass-aarch64` |
| `proton-pass-biometrics/` | x86_64 | Proton Pass with **fingerprint unlock** (fprintd + polkit), bundled Electron — see its [README](proton-pass-biometrics/README.md) |

Both Proton Pass packages install `/usr/bin/proton-pass` and conflict with
`proton-pass` / `proton-pass-bin`; each builds for one architecture only.

The rest of this README covers the aarch64 packages. Upstream ships no arm64
Linux binaries, and the stock AUR recipe fails sign-in there with
*"Your session could not be resumed."* `electron39-bin` is the pinned upstream
linux-arm64 Electron, since Arch ARM's `extra` repo has no `electron` package.

## Install

```bash
git clone https://github.com/circumspace/pkgbuilds.git
cd pkgbuilds

# 1) Electron runtime (dependency of the pass package)
cd electron39-bin && makepkg -si && cd ..

# 2) Proton Pass (source build, ~3-5 min; needs nodejs-lts-jod, rustup, yarn from
#    extra/ and network for the Rust toolchain fetch)
cd proton-pass-aarch64 && makepkg -si
```

Prebuilt `proton-pass-1.41.1-2-aarch64.pkg.tar.xz` (built before the rename) / `electron39-bin-39.8.10-1-aarch64.pkg.tar.xz`
may be attached to [GitHub Releases](https://github.com/circumspace/pkgbuilds/releases) — then: `sudo pacman -U <file>.pkg.tar.xz`.

## What's different from the AUR `proton-pass` recipe (and why)

- **Sign-in fix (the big one).** The desktop app authenticates via cookies and rewrites
  them `SameSite=None` **only when `app.isPackaged`** is true — which a system-Electron
  launch (`electron39 /usr/share/proton-pass/app.asar`) never is. Without the rewrite
  Chromium drops every auth cookie (renderer is `file://`), login dies at the first
  API call: `lock/check` → 401, cookie-mode `auth/refresh` → 422, session torn down.
  Patched: `isProdEnv()` also honors `PROTON_PASS_SYSTEM_PACKAGE=1`, exported by the
  wrapper. Cookie-mode sign-in validation in progress on aarch64 (token-mode path
  confirmed working with the same build); updated to "verified" after final test.
  (Upstream report: linked issue/PR placeholder.)
- **`electron39-bin`** instead of `electron`: exact upstream pin (39.8.10), official
  linux-arm64 zip; Arch ARM has no system `electron`.
- **`rustup` + build-local toolchain** (`RUSTUP_HOME="$srcdir/.rustup"`) instead of `rust`:
  no `rust` package on archlinuxarm.org; builder's home untouched.
- **`SHARP_IGNORE_GLOBAL_LIBVIPS=1`**: otherwise sharp's postinstall enters a node-gyp
  build yarn 4 refuses; prebuilt arm64 binaries are used.
- **`npmMinimalAgeGate: 0`** (build-local): age gate breaks reproducible installs.
- **Berry env-var form** `NODE_ENV=production yarn exec electron-forge package`:
  `yarn exec 'NODE_ENV=… pkg'` silently drops the env var under yarn 4 and packages a dev build.
- **Versioned source + pinned sha256**: codeload re-serializes tag tarballs, breaking
  checksums over time (this is what broke the current AUR recipe at 1.38.2).

## Known issues / notes

- Upstream `proton-pass-desktop` does not build or test linux-aarch64; this recipe fills
  that gap for the napi native module (compiled via build-local rustup). If a future
  release hardcodes targets again, `native/build.js` is where to look.
- Tray icon under system Electron needs the `resourcesPath` sed already in the PKGBUILD.
- Legacy-auth workaround (not recommended, kept for reference):
  `localStorage.setItem('ps_legacy','1')` → token mode; bypasses the cookie path entirely.

## Updating versions

```bash
cd proton-pass-aarch64
# bump pkgver/pkgrel (and source url) in PKGBUILD
updpkgsums         # regenerate checksums from the pinned archive URL
makepkg -si
```

License of packaging: GPL-3.0-or-later (matches upstream PKGBUILD header).
