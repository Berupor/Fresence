#!/usr/bin/env bash
set -euo pipefail

REPO="Berupor/Fresence"
BINARY="fresence"
INSTALL_DIR="$HOME/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_DIR="$DATA_DIR/fresence/desktop"
RELEASE="https://github.com/${REPO}/releases/latest/download"

case "$(uname -m)" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)
        echo "error: unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
ASSET="${BINARY}-linux-${ARCH}"
DESKTOP_ASSET="${BINARY}-desktop-linux-${ARCH}.tar.gz"

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

echo "downloading ${ASSET}..."
fetch "$RELEASE/$ASSET" "$TMP/$ASSET"
fetch "$RELEASE/checksums.txt" "$TMP/checksums.txt"
(cd "$TMP" && grep " ${ASSET}\$" checksums.txt | sha256sum -c --quiet -)

chmod +x "$TMP/$ASSET"
mkdir -p "$INSTALL_DIR" "$UNIT_DIR"
mv "$TMP/$ASSET" "$INSTALL_DIR/$BINARY"

install_desktop() {
    echo "downloading ${DESKTOP_ASSET}..."
    fetch "$RELEASE/$DESKTOP_ASSET" "$TMP/$DESKTOP_ASSET"
    (cd "$TMP" && grep " ${DESKTOP_ASSET}\$" checksums.txt | sha256sum -c --quiet -)
    tar -C "$TMP" -xzf "$TMP/$DESKTOP_ASSET"
    mkdir -p "$(dirname "$DESKTOP_DIR")" "$DATA_DIR/applications"
    rm -rf "$DESKTOP_DIR"
    mv "$TMP/Fresence" "$DESKTOP_DIR"
    ln -sfn "$DESKTOP_DIR/bin/Fresence" "$INSTALL_DIR/fresence-desktop"
    cat > "$DATA_DIR/applications/fresence.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Fresence
Exec=$INSTALL_DIR/fresence-desktop %u
Icon=$DESKTOP_DIR/lib/Fresence.png
Categories=Network;
MimeType=x-scheme-handler/fresence;
EOF
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$DATA_DIR/applications" || true
    fi
    if command -v xdg-mime &>/dev/null; then
        xdg-mime default fresence.desktop x-scheme-handler/fresence || true
    fi
    echo "installed $INSTALL_DIR/fresence-desktop"
}

if [ "$ARCH" = "amd64" ]; then
    install_desktop
fi

cat > "$UNIT_DIR/fresence.service" <<EOF
[Unit]
Description=Fresence agent
After=graphical-session.target

[Service]
ExecStart=$INSTALL_DIR/$BINARY run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now fresence.service

echo "installed $INSTALL_DIR/$BINARY and started fresence.service"
case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) echo "add $INSTALL_DIR to PATH" ;;
esac
echo
echo "then one of:"
echo "  fresence join <invite>        first device, by an invite"
echo "  fresence link <offer>         accept an offer shown by your linked device"
echo "  fresence link --server <url>  show an offer to scan from your linked device"
