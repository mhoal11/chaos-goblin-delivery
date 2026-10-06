#!/usr/bin/env bash

# Chaos Goblin Delivery: installer
# Installs into your home folder; no sudo needed.
#
#   ./install.sh

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
LIB="$HOME/.local/lib/chaos-goblin"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/chaos-goblin"

mkdir -p "$BIN" "$LIB" "$CONF/recipients"

install -m 755 "$SRC"/bin/scan "$SRC"/bin/ocr "$SRC"/bin/send-to "$BIN"/
install -m 755 "$SRC"/lib/detect-pdf-title "$LIB"/

# Never overwrite settings you've already edited.
[[ -f "$CONF/chaos-goblin.conf" ]] ||
    install -m 644 "$SRC"/config/chaos-goblin.conf "$CONF"/
[[ -f "$CONF/recipients/desktop.conf" ]] ||
    install -m 600 "$SRC"/config/recipients/example.conf "$CONF/recipients/desktop.conf"

echo "Installed: scan, ocr, send-to -> $BIN"
echo
echo "Next steps:"
echo "  1. Edit $CONF/recipients/desktop.conf (Windows PC address and share)"
echo "  2. Create ~/.smbcredentials from config/smbcredentials.example, then: chmod 600 ~/.smbcredentials"
echo "  3. Test:  send-to desktop some-file.pdf"

missing=()
for cmd in smbclient ocrmypdf pdftotext img2pdf scanimage zenity python3; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if (( ${#missing[@]} )); then
    echo
    echo "Missing tools: ${missing[*]}"
    echo "Debian/Ubuntu/Parrot:  sudo apt install smbclient ocrmypdf poppler-utils img2pdf sane-utils zenity"
fi
