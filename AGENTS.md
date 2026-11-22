# AGENTS.md — pkgbuilds

## Private build system — do not publish or rely on it in package docs

The build infrastructure (the `daemon` ssh host, its Tailscale address, and
the self-hosted forge) is **private**. Never reference hostnames, IPs, or
build-tool paths from this infrastructure in public-facing package files
(`PKGBUILD`, package `README.md`, `.SRCINFO`) — those files are installable
via paru by anyone with repo access. `AGENTS.md` is the only place that
describes them.

## Building packages: podman containers preferred, never this laptop

This laptop is not meant for compile work. Heavy builds (pnpm installs,
webpack, cargo, electron-forge) must run remotely — **preferably inside
podman build containers** (reproducible, disposable, no daemon-host state):

- Container recipe: Arch base image → `pacman -Syu base-devel nodejs-lts-*`
  (or mise) → mount the package dir → `makepkg` → copy out the
  `*.pkg.tar.zst`. Package builds need no root on the host; podman is
  rootless.
- Until a per-package container exists, the stopgap is building directly on
  the `daemon` ssh host (12 cores, 62 GB RAM). `proton-pass-biometrics` has
  a ready-made stopgap script:

  ```sh
  cd proton-pass-biometrics
  ./build-on-daemon.sh          # rsyncs sources, builds remotely, fetches the package
  sudo pacman -U proton-pass-biometrics-<ver>-1-x86_64.pkg.tar.zst   # local install needs a password
  ```

  The script provisions its own toolchain on the daemon via mise
  (node 24.22.3 with bundled corepack, rust 1.99.0) and runs
  `makepkg -f --nodeps`, touching no pacman packages remotely. It always
  wipes the remote `src/`/`pkg/` first — patches are not idempotent, and
  makepkg re-runs `prepare()` over an existing tree on reruns.

When adding a new package or touching build scripts, set up the podman
container path rather than growing the daemon-host shortcut.

## Gotchas

- **Node ≥25 silently breaks electron-forge packaging** (exit 0, no `out/`).
  pnpm and forge's child processes re-resolve `node` from PATH —
  `mise exec node@24 -- makepkg` does NOT protect this; the Node 24 bin
  directory must come before `/usr/bin` in PATH. `proton-pass-biometrics`'s
  `build-on-daemon.sh` handles it, and its PKGBUILD's `build()` guards the
  resolved node major version and fails loudly otherwise.
- When a remote build fails, debug on the daemon (its own logs, e.g.
  `/tmp/makepkg.log`) rather than re-running heavy steps locally.
- Local repo checkouts are fine for editing PKGBUILDs/patches; only builds
  go remote.
