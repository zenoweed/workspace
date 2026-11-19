#!/bin/sh
# Installs workspace.sh as the `ws` command.
#   curl -fsSL https://raw.githubusercontent.com/zenoweed/workspace/main/install.sh | sh
# Set WS_BIN to install somewhere other than ~/.local/bin.
set -eu

BIN="${WS_BIN:-$HOME/.local/bin}"
URL="https://raw.githubusercontent.com/zenoweed/workspace/main/workspace.sh"

mkdir -p "$BIN"
curl -fsSL "$URL" -o "$BIN/ws"
chmod +x "$BIN/ws"
echo "Installed: $BIN/ws"

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "Add it to your PATH:  echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.bashrc && . ~/.bashrc" ;;
esac

command -v fzf >/dev/null 2>&1 || echo "Optional: install fzf for the interactive workspace picker."
echo "Run 'ws help' to get started."
