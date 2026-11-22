# proton-pass-biometrics

Source-built Arch package of [Proton Pass](https://proton.me/pass) desktop
(`ProtonMail/WebClients`, tag `proton-pass@1.43.0`) with Linux fingerprint
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

```
makepkg -sf
sudo pacman -U proton-pass-biometrics-1.43.0-1-x86_64.pkg.tar.zst
```

pacman will replace `proton-pass-bin` (`conflicts` + `provides`). Build
requirements: `nodejs-lts-jod` (Node 24 — **required**, see below) and
`rust`. Corepack fetches pnpm 12.4.1 to package the pinned logger source and
pnpm 12.13.0 for the desktop workspace. Runtime: `fprintd` + `gnome-keyring` + `polkit`,
with at least one enrolled finger (`fprintd-enroll`).

Upstream's `.npmrc` points `@protontech` packages to Proton's Nexus registry,
which may be unreachable; `@protontech/logger@0.0.5` is also absent from the
public npm registry. The PKGBUILD:

- Fetches the pinned [WebPackages source](https://github.com/ProtonMail/WebPackages/tree/6e219abb11d996376792dc2d0f97a0f140c8a163/packages/logger)
  and packs the logger with pnpm 12.4.1, linking its workspace dependencies.
- Checks the resulting tarball against the SHA-512 in the upstream lockfile,
  then redirects that lockfile entry to the local tarball.
- Fetches the other `@protontech` packages from the public npm registry.

Neither Nexus access nor a pre-populated pnpm cache is required. When updating
the desktop release, check the locked logger version and integrity; update the
pinned source, tarball checksum and lockfile substitution if they change.

> Node ≥25 must not drive the build: its zip stack hangs silently inside
> electron-forge's extraction, so the build "succeeds" without ever
> producing `out/`. If your default `node` is newer, prefix makepkg with
> the Node 24 one, e.g. `mise exec node@24 -- makepkg` or use the
> system `nodejs-lts-jod`.

## Assumptions

- The gnome-keyring login collection is unlocked at session start (PAM).
  If it is not, `get_secret` fails and the app falls back to password
  unlock — see `gnome-keyring-pam` in `/etc/pam.d/system-auth`.
- The fingerprint prompt comes from the session's polkit authentication
  agent; without one, `pkcheck --allow-user-interaction` cannot prompt and
  verification fails closed (password unlock still works).
