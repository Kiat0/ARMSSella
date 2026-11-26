<p align="center">
  <img src="docs/public/logo.png" width="128" height="128" alt="ARMSSella Logo" />
</p>

<h1 align="center">ARMSSella</h1>

<p align="center">
  <strong>ARM64 Steam Game & Depot Management Suite for Armada OS & DroidDeck.</strong>
</p>

<p align="center">
  Dedicated ARM64 fork of <a href="https://github.com/niwia/ASSella">niwia/ASSella</a> built for ARM handhelds running <strong>Armada OS</strong> (Fedora <code>bootc</code> / Gamescope) and <strong>DroidDeck</strong> (unrooted Android Linux userland).
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License"></a>
  <a href="docs/arm64.md"><img src="https://img.shields.io/badge/platform-Armada%20OS%20(ARM64)-blue.svg" alt="Armada OS"></a>
  <a href="docs/droiddeck.md"><img src="https://img.shields.io/badge/platform-DroidDeck%20(Android)-green.svg" alt="DroidDeck"></a>
</p>

---

### Supported Targets

- **Armada OS (`aarch64`):** Self-contained `ARMSSella-arm64.AppImage` (static FUSE3 runtime, bundled Python 3.13 + `.NET 9` ARM64, Wayland/Gamescope native, `steamrtarm64` & `linuxarm64` manifest support) or source install via `scripts/install-armada.sh`. See [docs/arm64.md](docs/arm64.md).
- **DroidDeck (Android ARM64):** FUSE-free `ARMSSella-arm64-portable.tar.gz` bundle, AppImage import via DroidDeck's **Add an app**, or source install via `scripts/install-droiddeck.sh` — with automatic Android `.NET 9` CoreCLR flags, `systemd`-free fallbacks, `/mnt/droiddeck-sd` library discovery, and FEX wrapping for x86 helpers. See [docs/droiddeck.md](docs/droiddeck.md).

---

### Quick Start

#### DroidDeck (Portable Bundle — Recommended)
```bash
bash scripts/install-droiddeck.sh --portable ~/Downloads/ARMSSella-arm64-portable.tar.gz
armssella
```

#### DroidDeck (From Source)
```bash
bash scripts/install-droiddeck.sh
armssella
```

#### Armada OS (AppImage)
```bash
chmod +x ARMSSella-arm64.AppImage
./ARMSSella-arm64.AppImage
```

#### Armada OS (From Source)
```bash
bash scripts/install-armada.sh
armssella
```

---

### Upstream Attribution

ARMSSella is a community ARM64 fork of **[ASSella](https://github.com/niwia/ASSella)** (GPL-3.0). For general ASSella documentation and Hubcap setup guides, see **[assella.pages.dev](https://assella.pages.dev/)**.
