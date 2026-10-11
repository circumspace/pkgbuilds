# pkgbuilds

Custom Arch Linux builds of software I use: patched, source-built, or packaged
for architectures upstream does not ship. Each directory is one package with its
own `PKGBUILD` and, where there is more to say, a `README.md`.

| Package | Arch | Notes |
|---|---|---|
| [`proton-pass-aarch64`](proton-pass-aarch64/) | aarch64 | Proton Pass Desktop for Arch Linux ARM on system Electron |
| [`electron39-bin`](electron39-bin/) | aarch64 | Electron 39 runtime for `proton-pass-aarch64` |
| [`proton-pass-biometrics`](proton-pass-biometrics/) | x86_64 | Proton Pass Desktop with fingerprint unlock (fprintd + polkit) |

## Build and install

```bash
git clone https://github.com/circumspace/pkgbuilds.git
cd pkgbuilds/<package>
makepkg -si
```

Some packages depend on others in this repo; build those first. Prebuilt
packages, when there are any, are attached to
[GitHub Releases](https://github.com/circumspace/pkgbuilds/releases):
`sudo pacman -U <file>.pkg.tar.*`.

## License

Packaging files are GPL-3.0-or-later unless a package states otherwise. The
software itself keeps its upstream license.
