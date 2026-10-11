# pkgbuilds

Custom Arch Linux builds of software I use: patched, source-built, or packaged
for architectures upstream does not ship. Each directory is one package with its
own `PKGBUILD` and, where there is more to say, a `README.md`.

| Package | Arch | Notes |
|---|---|---|
| [`proton-pass`](proton-pass/) | aarch64 | Proton Pass Desktop for Arch Linux ARM on system Electron |
| [`electron39-bin`](electron39-bin/) | aarch64 | Electron 39 runtime for `proton-pass` |
| [`proton-pass-biometrics`](proton-pass-biometrics/) | x86_64 | Proton Pass Desktop with fingerprint unlock (fprintd + polkit) |

## Install with paru

paru (2.0 or later) can track this repo like the AUR. Add it to
`/etc/paru.conf` or `~/.config/paru/paru.conf`:

```ini
[circumspace]
Url = https://github.com/circumspace/pkgbuilds
```

Then `paru -Sya` fetches it and `paru -S <package>` builds and installs a
package, dependencies from this repo included. `paru -Syu` picks up updates.
Packages here take priority over AUR packages of the same name, so `proton-pass`
comes from this repo once it is added.

## Build and install by hand

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
