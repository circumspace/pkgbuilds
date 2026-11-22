# AGENTS.md — pkgbuilds

## Building packages: use the `daemon` ssh host, not this laptop

This laptop is not meant for compile work. Heavy builds (pnpm installs,
webpack, cargo, electron-forge) must be handed off to the `daemon` ssh host
(12 cores, 62 GB RAM, Tailscale).

`proton-pass-biometrics` has a ready-made handoff script:

```sh
cd proton-pass-biometrics
./build-on-daemon.sh          # rsyncs sources, builds remotely, fetches the package
sudo pacman -U proton-pass-biometrics-<ver>-1-x86_64.pkg.tar.zst   # local install needs a password
```

The script provisions its own toolchain on the daemon via mise
(node 24.22.3 with bundled corepack, rust 1.99.0) and runs
`makepkg -f --nodeps`, touching no pacman packages remotely. It always wipes
the remote `src/`/`pkg/` first — patches are not idempotent, and makepkg
re-runs `prepare()` over an existing tree on reruns.

For other packages, follow the same pattern: rsync the package dir + sources
to `daemon:builds/<pkg>/`, run makepkg there under `mise x <tools>`, rsync the
`*.pkg.tar.zst` back. Toolchains install with `mise install <tool>@<version>` —
no root needed on the daemon.

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
