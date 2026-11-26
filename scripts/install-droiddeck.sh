#!/usr/bin/env bash
# ==============================================================================
# install-droiddeck.sh — DroidDeck (Android ARM64 Linux Userland) Installer
# ==============================================================================
# Installs ASSella inside DroidDeck's executable Linux userland (~/.local/share)
# without requiring root, FUSE, or systemd.
#
# Supports two modes:
#   1. Source install (default): sets up ~/.dotnet (ARM64 .NET 9), Python .venv,
#      native ARM64 wireproxy, launcher script, and KDE/Gaming Mode shortcuts.
#   2. Portable bundle install (--portable <path-to-ASSella-arm64-portable.tar.gz>):
#      extracts the self-contained ARM64 bundle (bundled Python 3.13 + PyQt6 +
#      .NET 9) with zero compilation or host dependency requirements.
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}=== ARMSSella DroidDeck (ARM64) Installer ===${NC}"

FORCE=0
PORTABLE_TAR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE=1
            shift
            ;;
        --portable|-p)
            PORTABLE_TAR="${2:-}"
            if [[ -z "$PORTABLE_TAR" ]]; then
                echo -e "${RED}Error: --portable requires a path to ARMSSella-arm64-portable.tar.gz${NC}" >&2
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--portable <ARMSSella-arm64-portable.tar.gz>] [--force]"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# 1. Architecture & Environment Check
ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" && "$FORCE" -eq 0 ]]; then
    echo -e "${YELLOW}Warning: Detected architecture '$ARCH' is not ARM64 (aarch64).${NC}"
    echo "Pass '--force' to continue anyway."
    exit 1
fi

IS_DD=0
if [[ -n "${DD_DESKTOP:-}${DD_LAUNCH_DIR:-}${DD_INSIDE:-}${DDNATV_ROOT:-}${DD_STEAM_CLIENT_ARCH:-}" ]] || [[ -x /usr/local/bin/droiddeck-session ]]; then
    IS_DD=1
    echo -e "${GREEN}✓ DroidDeck Linux userland detected.${NC}"
else
    echo -e "${YELLOW}Note: DroidDeck markers not detected; continuing with FUSE-free/systemd-free ARM64 setup.${NC}"
fi

# Always install inside the executable Linux userland HOME (never Android noexec /sdcard)
HOME_DIR="${HOME:-/root}"
INSTALL_DIR="${HOME_DIR}/.local/share/ARMSSella"
PORTABLE_DIR="${HOME_DIR}/.local/share/ARMSSella-portable"
BIN_DIR="${HOME_DIR}/.local/bin"
DOTNET_DIR="${HOME_DIR}/.dotnet"
APP_DIR="${HOME_DIR}/.local/share/applications"
ICON_DIR_SVG="${HOME_DIR}/.local/share/icons/hicolor/scalable/apps"
ICON_DIR_PNG="${HOME_DIR}/.local/share/icons/hicolor/256x256/apps"

mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR_SVG" "$ICON_DIR_PNG"

# Verify target directory is not mounted noexec
probe_exec=$(mktemp "$BIN_DIR/.armssella_exec_probe.XXXXXX")
printf '#!/bin/sh\nexit 0\n' > "$probe_exec"
chmod +x "$probe_exec"
if ! "$probe_exec" 2>/dev/null; then
    rm -f "$probe_exec"
    echo -e "${RED}Error: $BIN_DIR appears to be on a noexec filesystem (such as Android shared storage).${NC}" >&2
    echo "Run this installer inside DroidDeck's Konsole/terminal with HOME inside the Linux rootfs." >&2
    exit 1
fi
rm -f "$probe_exec"

# Helper: write desktop entry & optional Desktop shortcut
install_shortcuts() {
    local launcher_path="$1"
    local icon_svg_src="$2"
    local icon_png_src="$3"

    if [[ -f "$icon_svg_src" ]]; then
        cp -f "$icon_svg_src" "$ICON_DIR_SVG/armssella.svg"
    fi
    if [[ -f "$icon_png_src" ]]; then
        cp -f "$icon_png_src" "$ICON_DIR_PNG/armssella.png"
    fi

    local desktop_file="$APP_DIR/armssella.desktop"
    local desktop_tmp
    desktop_tmp=$(mktemp "${APP_DIR}/.armssella.desktop.tmp.XXXXXX")
    cat << EOF > "$desktop_tmp"
[Desktop Entry]
Name=ARMSSella
GenericName=Game Depot Downloader
Comment=Steam Game & Depot Management Suite (ARM64 — DroidDeck)
Exec=$launcher_path %u
Icon=armssella
Terminal=false
Type=Application
Categories=Utility;Game;
StartupNotify=true
StartupWMClass=ARMSSella
EOF
    chmod 0644 "$desktop_tmp"
    rm -f "$desktop_file"
    mv -f "$desktop_tmp" "$desktop_file"

    if [[ -d "${HOME_DIR}/Desktop" ]]; then
        cp -f "$desktop_file" "${HOME_DIR}/Desktop/ARMSSella.desktop"
        chmod +x "${HOME_DIR}/Desktop/ARMSSella.desktop" 2>/dev/null || true
    fi
    ln -sf "$launcher_path" "$BIN_DIR/assella"
    echo -e "${GREEN}✓ Created launcher: $launcher_path (alias: $BIN_DIR/assella)${NC}"
    echo -e "${GREEN}✓ Created desktop entry: $desktop_file${NC}"
}

# ==============================================================================
# Mode A: Self-contained Portable Bundle (Zero host Python/.NET deps)
# ==============================================================================
if [[ -n "$PORTABLE_TAR" ]]; then
    if [[ ! -f "$PORTABLE_TAR" ]]; then
        echo -e "${RED}Error: Portable bundle not found: $PORTABLE_TAR${NC}" >&2
        exit 1
    fi
    echo -e "\n${BLUE}[1/2] Extracting self-contained ARM64 portable bundle to $PORTABLE_DIR...${NC}"
    tmp_extract=$(mktemp -d "${HOME_DIR}/.local/share/.armssella-portable-tmp.XXXXXX")
    tar -xzf "$PORTABLE_TAR" -C "$tmp_extract"
    if [[ ! -x "$tmp_extract/AppDir/AppRun" ]]; then
        rm -rf "$tmp_extract"
        echo -e "${RED}Error: Archive does not contain AppDir/AppRun.${NC}" >&2
        exit 1
    fi
    rm -rf "$PORTABLE_DIR"
    mv "$tmp_extract/AppDir" "$PORTABLE_DIR"
    rm -rf "$tmp_extract"

    echo -e "\n${BLUE}[2/2] Creating DroidDeck launcher and shortcuts...${NC}"
    LAUNCHER="$BIN_DIR/armssella"
    cat << 'EOF' > "$LAUNCHER"
#!/usr/bin/env bash
# ARMSSella DroidDeck Portable Launcher (FUSE-free, bundled Python 3.13 + .NET 9)
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export QTWEBENGINE_DISABLE_SANDBOX=1
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_EnableWriteXorExecute="${DOTNET_EnableWriteXorExecute:-0}"
export COMPlus_EnableWriteXorExecute="${COMPlus_EnableWriteXorExecute:-0}"
export DOTNET_gcServer="${DOTNET_gcServer:-0}"
export DOTNET_EnableDiagnostics="${DOTNET_EnableDiagnostics:-0}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export APPIMAGE_EXTRACT_AND_RUN=1
unset LD_AUDIT

PORTABLE_DIR="${HOME:-/root}/.local/share/ARMSSella-portable"
exec "$PORTABLE_DIR/AppRun" "$@"
EOF
    chmod +x "$LAUNCHER"

    install_shortcuts \
        "$LAUNCHER" \
        "$PORTABLE_DIR/bin/src/res/logo/icon.svg" \
        "$PORTABLE_DIR/bin/src/res/logo/icon.png"

    echo -e "\n${BOLD}${GREEN}=== DroidDeck Portable Installation Complete! ===${NC}"
    echo -e "Launch from Konsole with: ${BOLD}armssella${NC}"
    echo -e "Or open ${BOLD}ARMSSella${NC} from the Desktop / Application Menu, or add ${BOLD}$LAUNCHER${NC} as a Non-Steam Game."
    exit 0
fi

# ==============================================================================
# Mode B: Source Install inside DroidDeck Linux Userland
# ==============================================================================
echo -e "\n${BLUE}[1/5] Checking system dependencies...${NC}"
MISSING_DEPS=()
for cmd in python3 curl git; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required commands: ${MISSING_DEPS[*]}${NC}" >&2
    exit 1
fi
echo -e "${GREEN}✓ Core tools (python3, curl, git) present.${NC}"

mkdir -p "$INSTALL_DIR"

# Android/proot-safe .NET 9 environment during installation and probing
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_EnableWriteXorExecute=0
export COMPlus_EnableWriteXorExecute=0
export DOTNET_gcServer=0
export DOTNET_EnableDiagnostics=0
export DOTNET_CLI_TELEMETRY_OPTOUT=1

echo -e "\n${BLUE}[2/5] Checking Microsoft .NET 9 Runtime (ARM64)...${NC}"
if [[ -x "$DOTNET_DIR/dotnet" ]] && "$DOTNET_DIR/dotnet" --list-runtimes 2>/dev/null | grep -q "Microsoft.NETCore.App 9"; then
    echo -e "${GREEN}✓ .NET 9 runtime already installed in $DOTNET_DIR.${NC}"
else
    echo "Downloading and installing official .NET 9 runtime for linux-arm64..."
    DOTNET_SCRIPT=$(mktemp)
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$DOTNET_SCRIPT"
    chmod +x "$DOTNET_SCRIPT"
    bash "$DOTNET_SCRIPT" --runtime dotnet --channel 9.0 --architecture arm64 --install-dir "$DOTNET_DIR"
    rm -f "$DOTNET_SCRIPT"
    echo -e "${GREEN}✓ .NET 9 runtime (ARM64) installed successfully.${NC}"
fi

echo -e "\n${BLUE}[3/5] Setting up ARMSSella source files...${NC}"
REPO_URL="${ARMSSELLA_REPO_URL:-https://github.com/Kiat0/ARMSSella.git}"
BRANCH="${ARMSSELLA_BRANCH:-armada-main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$SCRIPT_DIR/src/main.py" ]] && [[ "$(realpath "$SCRIPT_DIR")" != "$(realpath "$INSTALL_DIR")" ]]; then
    echo "Copying local repository files from $SCRIPT_DIR to $INSTALL_DIR..."
    cp -rf "$SCRIPT_DIR"/* "$INSTALL_DIR"/
elif [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Updating existing installation in $INSTALL_DIR..."
    git -C "$INSTALL_DIR" fetch origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    git -C "$INSTALL_DIR" pull origin "$BRANCH"
else
    echo "Cloning from $REPO_URL ($BRANCH branch)..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi
echo -e "${GREEN}✓ Source files ready at $INSTALL_DIR.${NC}"

echo -e "\n${BLUE}[4/5] Setting up Python virtual environment...${NC}"
VENV_DIR="$INSTALL_DIR/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --upgrade pip --quiet
echo "Installing Python dependencies (PyQt6, requests, etc.)..."
"$VENV_DIR/bin/pip" install -r "$INSTALL_DIR/requirements.txt" --quiet
echo -e "${GREEN}✓ Python virtual environment configured.${NC}"

# Native ARM64 wireproxy binary for Kuroko stealth proxy
NEED_WIREPROXY=0
if [[ ! -x "$INSTALL_DIR/src/deps/wireproxy" ]]; then
    NEED_WIREPROXY=1
elif command -v file &>/dev/null && file -b "$INSTALL_DIR/src/deps/wireproxy" 2>/dev/null | grep -q "x86-64"; then
    NEED_WIREPROXY=1
fi
if [[ "$NEED_WIREPROXY" -eq 1 ]]; then
    echo "Downloading native ARM64 wireproxy (v1.1.3)..."
    WP_TMP=$(mktemp -d)
    if curl -fsSL --retry 3 "https://github.com/windtf/wireproxy/releases/download/v1.1.3/wireproxy_linux_arm64.tar.gz" -o "$WP_TMP/wireproxy.tar.gz" 2>/dev/null; then
        tar -xzf "$WP_TMP/wireproxy.tar.gz" -C "$WP_TMP" 2>/dev/null || true
        if [[ -f "$WP_TMP/wireproxy" ]]; then
            mkdir -p "$INSTALL_DIR/src/deps"
            cp -f "$WP_TMP/wireproxy" "$INSTALL_DIR/src/deps/wireproxy"
            chmod +x "$INSTALL_DIR/src/deps/wireproxy"
            echo -e "${GREEN}✓ Native ARM64 wireproxy installed.${NC}"
        fi
    fi
    rm -rf "$WP_TMP"
fi

echo -e "\n${BLUE}[5/5] Creating DroidDeck launcher, desktop entry, and icons...${NC}"
LAUNCHER="$BIN_DIR/armssella"
cat << 'EOF' > "$LAUNCHER"
#!/usr/bin/env bash
# ARMSSella DroidDeck Launcher (ARM64 / Android Linux userland)
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"
export QTWEBENGINE_DISABLE_SANDBOX=1
export DOTNET_ROOT="${HOME:-/root}/.dotnet"
export PATH="${HOME:-/root}/.dotnet:${HOME:-/root}/.local/bin:${PATH}"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
export DOTNET_EnableWriteXorExecute="${DOTNET_EnableWriteXorExecute:-0}"
export COMPlus_EnableWriteXorExecute="${COMPlus_EnableWriteXorExecute:-0}"
export DOTNET_gcServer="${DOTNET_gcServer:-0}"
export DOTNET_EnableDiagnostics="${DOTNET_EnableDiagnostics:-0}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export APPIMAGE_EXTRACT_AND_RUN=1
unset LD_AUDIT

INSTALL_DIR="${HOME:-/root}/.local/share/ARMSSella"
cd "$INSTALL_DIR" || exit 1
exec "$INSTALL_DIR/.venv/bin/python3" "$INSTALL_DIR/src/main.py" "$@"
EOF
chmod +x "$LAUNCHER"

install_shortcuts \
    "$LAUNCHER" \
    "$INSTALL_DIR/src/res/logo/icon.svg" \
    "$INSTALL_DIR/src/res/logo/icon.png"

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    if [[ -f "${HOME_DIR}/.bashrc" ]] && ! grep -q "export PATH=.*$BIN_DIR" "${HOME_DIR}/.bashrc"; then
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "${HOME_DIR}/.bashrc"
    fi
fi

echo -e "\n${BOLD}${GREEN}=== DroidDeck Installation Complete! ===${NC}"
echo -e "Ways to run ARMSSella on DroidDeck:"
echo -e "  • ${BOLD}Konsole / Terminal${NC}: Run '${BOLD}armssella${NC}'"
echo -e "  • ${BOLD}Desktop Mode (KDE Plasma)${NC}: Open ARMSSella from the Application Menu or Desktop icon"
echo -e "  • ${BOLD}Gaming Mode (Gamescope)${NC}: In Steam -> Games -> 'Add a Non-Steam Game' -> select '${BOLD}$LAUNCHER${NC}'"
echo -e "  • ${BOLD}Tip (AppImage)${NC}: You can also import ${BOLD}ARMSSella-arm64.AppImage${NC} via DroidDeck's 'Add an app' feature."
