# ASSella for DroidDeck (Android ARM64)

ASSella supports running inside **DroidDeck** (`Droid-Deck/DroidDeck`) on unrooted ARM64 Android handhelds and smartphones (such as AYN Odin, Retroid Pocket, and Snapdragon/Adreno devices).

---

## How DroidDeck Differs from Desktop Linux

DroidDeck runs Valve's Linux Steam client and an optional KDE Plasma desktop inside an unrooted Android Linux userland (either **native userland / `DDNATV_ROOT`** or **`proot`**):

1. **No FUSE Mounting:** Unrooted Android cannot mount SquashFS AppImages via FUSE.
   - Use **`ASSella-arm64-portable.tar.gz`** (extracted directly into `~/.local/share/ASSella-portable`), **or**
   - Import **`ASSella-arm64.AppImage`** through DroidDeck's built-in **Add an app** / `droiddeck-open` (which automatically unpacks and launches it via `droiddeck-appimage-run` / `droiddeck-appimage-exec` with `APPIMAGE_EXTRACT_AND_RUN=1`).
2. **Android `.NET 9` CoreCLR Compatibility:**
   - ASSella automatically detects DroidDeck (`DD_DESKTOP`, `DD_LAUNCH_DIR`, `DD_INSIDE`, `DDNATV_ROOT`, `DD_STEAM_CLIENT_ARCH`, or `/usr/local/bin/droiddeck-session`) and exports Android-safe .NET flags (`DOTNET_EnableWriteXorExecute=0`, `COMPlus_EnableWriteXorExecute=0`, `DOTNET_gcServer=0`, `DOTNET_EnableDiagnostics=0`, `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`) for DepotDownloader and Steamless.
3. **No `systemd`:**
   - Background `systemd --user` services (such as the Epsilon daemon or `assella-testing.service`) are automatically disabled cleanly without errors. The in-app Web UI server works normally while ASSella is open.
4. **Executable Storage (`noexec` Guard):**
   - Android shared storage (`/sdcard`, `/storage/emulated/0`, `/mnt/droiddeck-sd`) may be mounted `noexec`. Always install ASSella inside the Linux userland (`~/.local/share/...`). You can still download **game files** to `/mnt/droiddeck-sd/steamapps` or `/mnt/droiddeck-lib/*`.
5. **Steam Client & Library Discovery:**
   - Detects both native ARM64 Steam (`~/.local/share/Steam/steamrtarm64`) and DroidDeck's optional x86-64 FEX Steam client (`~/.droiddeck-x64/.local/share/Steam` when `DD_STEAM_CLIENT_ARCH=x86_64`).
   - Automatically discovers DroidDeck's SD card (`/mnt/droiddeck-sd`) and extra external libraries (`/mnt/droiddeck-lib/*`).
   - Wraps x86_64 helper binaries (such as `schema-grabber`) through `/usr/local/bin/droiddeck-fex` when available, and uses pure-Python **Steamless AIO** (`capstone` + `pycryptodome`) natively on ARM64.

---

## Installation Options

### Option 1: Portable Bundle (Recommended — Zero Host Dependencies)

Download `ASSella-arm64-portable.tar.gz` from GitHub Actions / Releases, then run inside DroidDeck's **Konsole** (Desktop Mode):

```bash
bash scripts/install-droiddeck.sh --portable ~/Downloads/ASSella-arm64-portable.tar.gz
```

Or extract manually:

```bash
mkdir -p ~/.local/share/ASSella-portable
tar -xzf ~/Downloads/ASSella-arm64-portable.tar.gz -C ~/.local/share/ASSella-portable --strip-components=1
~/.local/share/ASSella-portable/AppRun
```

### Option 2: Import AppImage in DroidDeck

1. Download `ASSella-arm64.AppImage` onto your device.
2. In DroidDeck, use **Add an app** (or double-click it inside Desktop Mode / Dolphin). DroidDeck unpacks it once via `droiddeck-open` and runs `AppRun` with `QT_QPA_PLATFORM="wayland;xcb"`.

### Option 3: Source Install (Fastest for Testing Local/Fork Changes)

Inside DroidDeck's **Konsole** (Desktop Mode):

```bash
git clone -b armada-main <your-fork-url> ~/Armssella
cd ~/Armssella
bash scripts/install-droiddeck.sh
assella
```

---

## Standalone Mode vs. SLSsteam on DroidDeck

- **Standalone Mode (Default):** Works immediately without modifying Steam. Download depots directly into your Steam library (`/root/.local/share/Steam/steamapps/common` or `/mnt/droiddeck-sd/steamapps/common`), run Steamless AIO / Goldberg as needed, or add games as Non-Steam Games.
- **SLSsteam ARM64:** If you install an `aarm64` preview of `SLSsteam.so` into `~/.local/share/SLSsteam/SLSsteam.so`, ASSella detects it automatically. Do **not** run standard x86 Headcrab on ARM64 Steam.

---

## Troubleshooting

- **Qt display issues in Desktop Mode vs Gaming Mode:** ASSella uses `QT_QPA_PLATFORM="wayland;xcb"`. If a specific DroidDeck display configuration renders better over XWayland, launch with:
  ```bash
  QT_QPA_PLATFORM=xcb assella
  ```
- **`.NET 9` crashes with `SIGSEGV` or `0x8007000E`:** Ensure you launch via `~/.local/bin/assella` or `AppRun` so `DOTNET_EnableWriteXorExecute=0` and `DOTNET_gcServer=0` are exported.
- **`Permission denied` running binaries from `/sdcard`:** Move ASSella into `~/.local/share/` (inside the Linux userland).
