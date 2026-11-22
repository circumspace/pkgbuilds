# proton-pass-biometrics

Source-built Arch package of [Proton Pass](https://proton.me/pass) desktop
(`ProtonMail/WebClients`, tag `proton-pass@1.44.1`) with Linux fingerprint
unlock added. The fork is carried entirely by two patches on top of the
upstream tarball; nothing else is vendored.

Replaces `proton-pass-bin` (same binary name `proton-pass`, same desktop
entry, bundled Electron — no system `electron` dependency).

## How it works

Upstream ships the full biometrics machinery for Windows and macOS and stubs
it out on Linux in three places. The patches replace those stubs:

- `0001-rust-linux-biometrics-backend.patch` — real implementation for
  `applications/pass-desktop/native/shared`:
  - `can_check_presence`: true iff fprintd (`net.reactivated.Fprint`) has a
    device with at least one enrolled finger for the current user **and**
    `pkcheck` is on PATH. Any failure is reported as `false`, never an error
    (upstream semantics: false hides the option).
  - `check_presence`: `pkcheck --allow-user-interaction --action-id
    ch.proton.pass.unlock --process <pid of the Electron main process>`.
    The action is `auth_self` for active local sessions, so polkit asks PAM,
    and `/etc/pam.d/polkit-1` puts `pam_fprintd.so` first with a password
    fallback — the desktop agent (Omarchy) shows the fingerprint prompt.
  - `get_secret`/`set_secret`/`delete_secret`: Secret Service (gnome-keyring
    login collection) via zbus, matching macOS keychain / Windows DPAPI
    semantics upstream uses. No app-level PIN prompt: the polkit/PAM path is
    the authentication, and it already has a password fallback.
  - A dismissed polkit prompt maps to upstream's biometric-cancelled
    response; other authorization failures remain biometric failures.
- `0002-ts-enable-linux-biometrics.patch` — the TS wiring: the platform
  factory in `src/lib/biometrics/index.ts` (new `biometrics.linux.ts`,
  same shape as the Windows factory, including the 1.44
  `assertPresenceVerified` contract), the `LockSetup.tsx` settings
  toggle, and `preload.ts`: upstream hardcodes
  `biometricsKeyAppBound: process.platform === 'darwin'`; the fork adds
  `linux` so the vault key persists in the keyring and biometric unlock
  survives app restarts (chosen over upstream's no-key-at-rest model for
  Windows-like stores).

The vault unlock key (`offlineKey_biometrics::<localID>` attribute `key`)
is stored in the keyring when the biometrics lock is enabled; unlocking
verifies presence through polkit and decrypts with that key.

## Layout

```
PKGBUILD
proton-pass.desktop             desktop entry (same as proton-pass-bin)
ch.proton.pass.unlock.policy     polkit action, installed to /usr/share/polkit-1/actions
0001-rust-linux-biometrics-backend.patch
0002-ts-enable-linux-biometrics.patch
```

## Build & install

The build is heavy (pnpm install of the whole pass-desktop tree, webpack, forge
packaging, cargo). Default to running it on the `daemon` ssh host, not the
laptop:

```sh
./build-on-daemon.sh    # rsyncs sources, builds remotely, fetches the package
sudo pacman -U proton-pass-biometrics-<ver>-1-x86_64.pkg.tar.zst
```

The script provisions its own toolchain on the daemon via mise (node 24.22.3 +
its bundled corepack, rust) and runs `makepkg -f --nodeps`, so no pacman
packages are touched remotely.

Building locally instead: `makepkg -s` installs missing official-repository
dependencies automatically.

```sh
makepkg -sf
sudo pacman -U proton-pass-biometrics-1.44.1-1-x86_64.pkg.tar.zst
```

Every runtime dependency in the `PKGBUILD` is available from Arch's `core` or
`extra` repository. The build dependencies are all in `extra`:

- `nodejs-lts-krypton`: Node 24; upstream requires Node `^24.22.1`. If the
  repository copy is older than 24.22.1 (pnpm enforces `engines` strictly,
  `.npmrc` sets `engine-strict=true`), build under a newer Node 24, e.g.
  `mise exec node@24.22 -- makepkg -f --nodeps` (see the Node note below).
- `corepack`: provides the `corepack` command and fetches the upstream-pinned
  pnpm 12.18.0 release.
- `rust`: builds the native modules; upstream declares no minimum Rust version.

No prerequisite package needs an AUR or manual installation. During the build,
pnpm downloads locked JavaScript dependencies from npm, and Cargo downloads
locked crates from crates.io. Runtime fingerprint unlock requires `fprintd`,
`gnome-keyring`, `polkit`, and at least one enrolled finger (`fprintd-enroll`).

Installing the package replaces `proton-pass-bin` through its `conflicts` and
`provides` metadata.

Upstream's `.npmrc` points `@protontech` packages to Proton's Nexus registry,
but all are also available on the public npm registry, including
`@protontech/logger@1.0.0`.

> Node ≥25 must not drive the build: its packaging path exits silently
> inside electron-forge (exit 0, no `out/`). pnpm and forge's child
> processes resolve `node` from PATH, so `mise exec node@24 -- makepkg`
> is NOT sufficient when `/usr/bin/node` is ≥25 — put the Node 24 bin
> directory at the front of PATH explicitly, or install the system
> `nodejs-lts-krypton`. The PKGBUILD's build() guards against a wrong
> `node` before the long install.

## Assumptions

- The gnome-keyring login collection is unlocked at session start (PAM).
  If it is not, `get_secret` fails and the app falls back to password
  unlock — see `gnome-keyring-pam` in `/etc/pam.d/system-auth`.
- The fingerprint prompt comes from the session's polkit authentication
  agent; without one, `pkcheck --allow-user-interaction` cannot prompt and
  verification fails closed (password unlock still works).
