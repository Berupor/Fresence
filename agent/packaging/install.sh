#!/usr/bin/env bash
set -euo pipefail

REPO="Berupor/Fresence"
INSTALL_DIR="$HOME/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_DIR="$DATA_DIR/fresence/desktop"
LAUNCHER="$INSTALL_DIR/fresence-desktop"
MENU_ENTRY="$DATA_DIR/applications/fresence.desktop"
# Keep in agreement with goAgentUnit and goAgentBinary in app/desktopApp/.../DesktopUpdate.kt.
OLD_AGENT_UNIT="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/fresence.service"
OLD_AGENT_BINARY="$INSTALL_DIR/fresence"
RELEASES="https://github.com/${REPO}/releases"
DESKTOP_ASSET="fresence-desktop-linux-amd64.tar.gz"
NOTICES_ASSET="fresence-third-party-notices.txt"
STALL_SECONDS=30

error() {
    echo "error: $1" >&2
    exit 1
}

FORCE=false
case "${1:-}" in
    "") ;;
    --force) FORCE=true ;;
    *) error "unknown option $1, the only one is --force" ;;
esac

if [ "$(uname -m)" != x86_64 ]; then
    error "unsupported architecture: $(uname -m), only x86_64 is built"
fi

have() { command -v "$1" &>/dev/null; }
have curl || have wget || error "curl or wget required"

fetch() {
    local show_progress=false
    [ "${3:-}" = progress ] && [ -t 2 ] && show_progress=true
    if have curl; then
        local flags=(-fSL --connect-timeout 15 --retry 3 --speed-limit 1 --speed-time "$STALL_SECONDS")
        if $show_progress; then curl "${flags[@]}" -# -o "$2" "$1"; else curl "${flags[@]}" -s -o "$2" "$1"; fi
    else
        local flags=(--timeout=15 --read-timeout="$STALL_SECONDS" --tries=3)
        if $show_progress; then wget "${flags[@]}" -qO "$2" --show-progress "$1"; else wget "${flags[@]}" -qO "$2" "$1"; fi
    fi
}

# Prints the last redirect target and the size of the final response.
probe() {
    if have curl; then
        curl -fsSLI --connect-timeout 15 "$1"
    else
        wget -q -S --spider --timeout=15 "$1" 2>&1
    fi | tr -d '\r' | awk 'tolower($1) == "location:" { url = $2 } tolower($1) == "content-length:" { size = $2 } END { print url, size + 0 }'
}

home() { echo "${1/#$HOME/\~}"; }

read -r LATEST_URL _ < <(probe "$RELEASES/latest") || true
TAG="${LATEST_URL##*/}"
[ "${TAG#v}" != "$TAG" ] || error "could not find the latest release on github.com, check the connection"
VERSION="${TAG#v}"
RELEASE="$RELEASES/download/$TAG"
read -r _ SIZE < <(probe "$RELEASE/$DESKTOP_ASSET") || true
INSTALLED="$(grep -o 'fresence\.release=[^ ]*' "$DESKTOP_DIR/lib/app/Fresence.cfg" 2>/dev/null | cut -d= -f2 || true)"

if [ "$INSTALLED" = "$VERSION" ] && ! $FORCE; then
    echo "Fresence $VERSION is already installed."
    echo "To reinstall: curl -fsSL https://raw.githubusercontent.com/${REPO}/master/agent/packaging/install.sh | bash -s -- --force"
    exit 0
fi

TITLE="Fresence $VERSION"
[ -n "$INSTALLED" ] && [ "$INSTALLED" != "$VERSION" ] && TITLE="Fresence $INSTALLED -> $VERSION"
SIZE_NOTE=""
[ "${SIZE:-0}" -gt 0 ] && SIZE_NOTE=" ($((SIZE / 1048576)) MB)"
echo "$TITLE for Linux x86_64$SIZE_NOTE"
echo
echo "Files go only to your home folder, no sudo:"
printf '  %-46s %s\n' \
    "$(home "$DESKTOP_DIR")" "the app" \
    "$(home "$LAUNCHER")" "launcher" \
    "$(home "$MENU_ENTRY")" "menu entry and fresence:// links"
echo

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch "$RELEASE/checksums.txt" "$TMP/checksums.txt" || error "could not download checksums.txt, check the connection and run the same command again"

install_notices() {
    fetch "$RELEASE/$NOTICES_ASSET" "$TMP/$NOTICES_ASSET" &&
        (cd "$TMP" && grep " ${NOTICES_ASSET}\$" checksums.txt | sha256sum -c --quiet -) &&
        mkdir -p "$DATA_DIR/fresence" &&
        mv "$TMP/$NOTICES_ASSET" "$DATA_DIR/fresence/$NOTICES_ASSET"
}

if ! install_notices 2>/dev/null; then
    echo "warning: could not download ${NOTICES_ASSET}" >&2
fi

[ -t 2 ] || echo "downloading ${DESKTOP_ASSET}..."
fetch "$RELEASE/$DESKTOP_ASSET" "$TMP/$DESKTOP_ASSET" progress ||
    error "download failed, check the connection and run the same command again"
(cd "$TMP" && grep " ${DESKTOP_ASSET}\$" checksums.txt | sha256sum -c --quiet -) ||
    error "the download is damaged, run the same command again"
echo "ok  checksum matches checksums.txt from the release"
tar -C "$TMP" -xzf "$TMP/$DESKTOP_ASSET"
mkdir -p "$(dirname "$DESKTOP_DIR")" "$(dirname "$MENU_ENTRY")" "$INSTALL_DIR"
rm -rf "$DESKTOP_DIR"
mv "$TMP/Fresence" "$DESKTOP_DIR"
ln -sfn "$DESKTOP_DIR/bin/Fresence" "$LAUNCHER"
# Keep in agreement with upgradeEntry in app/desktopApp/.../SchemeHandler.kt.
cat > "$MENU_ENTRY" <<EOF
[Desktop Entry]
Type=Application
Name=Fresence
Exec=$LAUNCHER %u
Icon=$DESKTOP_DIR/lib/Fresence.png
Categories=Network;
MimeType=x-scheme-handler/fresence;
StartupWMClass=fresence
EOF
if have update-desktop-database; then
    update-desktop-database "$(dirname "$MENU_ENTRY")" || true
fi
if have xdg-mime; then
    xdg-mime default fresence.desktop x-scheme-handler/fresence || true
fi

if [ -e "$OLD_AGENT_UNIT" ]; then
    systemctl --user disable --now fresence.service || systemctl --user stop fresence.service || true
    rm -f "$OLD_AGENT_UNIT"
    systemctl --user daemon-reload || true
    echo "ok  removed the old agent service"
fi
if [ -e "$OLD_AGENT_BINARY" ]; then
    rm -f "$OLD_AGENT_BINARY"
    echo "ok  removed the old agent $(home "$OLD_AGENT_BINARY")"
fi

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    setsid -f "$LAUNCHER" </dev/null >/dev/null 2>&1
    echo "ok  installed, Fresence is starting"
else
    echo "ok  installed, start Fresence from the menu or with $(home "$LAUNCHER")"
fi
echo "    it updates itself from now on"
echo "    to remove: rm -rf $(home "$DATA_DIR/fresence") $(home "$LAUNCHER") $(home "$MENU_ENTRY")"
