#!/usr/bin/env bash
set -euo pipefail

REPO="Berupor/Fresence"
INSTALL_DIR="$HOME/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_DIR="$DATA_DIR/fresence/desktop"
LAUNCHER="$INSTALL_DIR/fresence-desktop"
# Keep in agreement with goAgentUnit and goAgentBinary in app/desktopApp/.../DesktopUpdate.kt.
OLD_AGENT_UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/fresence.service"
OLD_AGENT_BINARY="$INSTALL_DIR/fresence"
RELEASE="https://github.com/${REPO}/releases/latest/download"
DESKTOP_ASSET="fresence-desktop-linux-amd64.tar.gz"
NOTICES_ASSET="fresence-third-party-notices.txt"

if [ "$(uname -m)" != x86_64 ]; then
    echo "error: unsupported architecture: $(uname -m), only x86_64 is built" >&2
    exit 1
fi

fetch() {
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$2" "$1"
    elif command -v wget &>/dev/null; then
        wget -qO "$2" "$1"
    else
        echo "error: curl or wget required" >&2
        exit 1
    fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch "$RELEASE/checksums.txt" "$TMP/checksums.txt"

install_notices() {
    fetch "$RELEASE/$NOTICES_ASSET" "$TMP/$NOTICES_ASSET" &&
        (cd "$TMP" && grep " ${NOTICES_ASSET}\$" checksums.txt | sha256sum -c --quiet -) &&
        mkdir -p "$DATA_DIR/fresence" &&
        mv "$TMP/$NOTICES_ASSET" "$DATA_DIR/fresence/$NOTICES_ASSET"
}

if ! install_notices 2>/dev/null; then
    echo "warning: could not download ${NOTICES_ASSET}" >&2
fi

echo "downloading ${DESKTOP_ASSET}..."
fetch "$RELEASE/$DESKTOP_ASSET" "$TMP/$DESKTOP_ASSET"
(cd "$TMP" && grep " ${DESKTOP_ASSET}\$" checksums.txt | sha256sum -c --quiet -)
tar -C "$TMP" -xzf "$TMP/$DESKTOP_ASSET"
mkdir -p "$(dirname "$DESKTOP_DIR")" "$DATA_DIR/applications" "$INSTALL_DIR"
rm -rf "$DESKTOP_DIR"
mv "$TMP/Fresence" "$DESKTOP_DIR"
ln -sfn "$DESKTOP_DIR/bin/Fresence" "$LAUNCHER"
# Keep in agreement with upgradeEntry in app/desktopApp/.../SchemeHandler.kt.
cat > "$DATA_DIR/applications/fresence.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Fresence
Exec=$LAUNCHER %u
Icon=$DESKTOP_DIR/lib/Fresence.png
Categories=Network;
MimeType=x-scheme-handler/fresence;
StartupWMClass=fresence
EOF
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DATA_DIR/applications" || true
fi
if command -v xdg-mime &>/dev/null; then
    xdg-mime default fresence.desktop x-scheme-handler/fresence || true
fi
echo "installed $LAUNCHER"

if [ -e "$OLD_AGENT_UNIT" ]; then
    systemctl --user disable --now fresence.service || systemctl --user stop fresence.service || true
    rm -f "$OLD_AGENT_UNIT"
    systemctl --user daemon-reload || true
    echo "removed the old agent service"
fi
if [ -e "$OLD_AGENT_BINARY" ]; then
    rm -f "$OLD_AGENT_BINARY"
    echo "removed the old agent $OLD_AGENT_BINARY"
fi

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    setsid -f "$LAUNCHER" </dev/null >/dev/null 2>&1
    echo "started Fresence"
else
    echo "start Fresence from the menu or with $LAUNCHER"
fi
