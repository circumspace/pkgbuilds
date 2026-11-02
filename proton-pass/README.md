# proton-pass (aarch64)

Proton Pass Desktop 1.43.0, source-built for **Arch Linux ARM (aarch64)**
and launched with system Electron 44.4.3 from `electron44-bin`. This is the
unmodified upstream application apart from the packaging adaptations below; it
does not include the Linux biometrics patches from `proton-pass-biometrics`.

## Install

```bash
git clone https://github.com/circumspace/pkgbuilds.git
cd pkgbuilds

# Install the Electron runtime first.
cd electron44-bin && makepkg -si && cd ..

# Build and install Proton Pass.
cd proton-pass && makepkg -si
```

The build dependencies are `nodejs-lts-krypton` (Node 24), `corepack`, and
`rustup`. Building also requires network access for Corepack's pinned pnpm
versions, npm packages, the Rust toolchain and crates, and Electron Forge's
build-time Electron download. The Rust toolchain and Cargo cache are kept under
`$srcdir`; they do not change the builder's rustup installation.

The 1.43.0 package and Electron dependency built under aarch64 QEMU. A
headless QEMU launch reached native-messaging startup, but the Chromium GPU or
renderer process failed; graphical startup and sign-in remain unverified on
native ARM hardware.

## Packaging details

- The wrapper runs `/usr/bin/electron44` with the installed `app.asar`, not a
  bundled Electron executable. The Forge-produced archive, unpacked native
  modules, and assets are installed under `/usr/share/proton-pass`.
- System Electron treats the app as unpackaged. The wrapper sets
  `PROTON_PASS_SYSTEM_PACKAGE=1` so the production cookie rewrite and other
  production behavior remain active; the window and tray icons use the installed
  assets. Cookie-mode sign-in on this release still needs runtime verification
  on aarch64.
- The launcher leaves Electron's profile selection unchanged from the previous
  system-Electron package and advertises the `protonpass://` scheme through its
  desktop entry. The desktop environment must register or select it as the
  scheme handler for external login.
- The Linux native addon and native-messaging host are built for the host ARM
  architecture with a build-local stable rustup toolchain. The host is installed
  as `/usr/share/proton-pass/assets/proton_pass_nm_host`; its socket lookup is
  aligned with the Electron profile (`$XDG_CONFIG_HOME/Proton Pass`, or
  `~/.config/Proton Pass` by default). Host logs remain under
  `$XDG_DATA_HOME/Proton Pass` (normally `~/.local/share/Proton Pass`).
- The release uses pnpm 12.13.0 through Corepack, a filtered workspace install,
  and the frozen lockfile. Public Proton dependencies resolve through npm. The
  unpublished `@protontech/logger` 0.0.5 tarball is reconstructed from a pinned
  WebPackages commit using pnpm 12.4.1 and verified against the lockfile's SHA-512
  before installation. `SHARP_IGNORE_GLOBAL_LIBVIPS=1` selects sharp's prebuilt
  ARM binaries rather than a system libvips build.

## Updating versions

Bump `pkgver` and reset `pkgrel` in `PKGBUILD`, then review upstream's workspace,
Node/pnpm/Electron versions, native build scripts, runtime paths and production
handling. Update the WebPackages commit and the expected reconstructed logger
SHA-512 if the lockfile changes. Regenerate the source checksums and `.SRCINFO`
after making those changes, then build and verify the package on aarch64.
