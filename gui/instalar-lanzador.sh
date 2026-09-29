#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GUI="$ROOT/gui/debian-trixie-gui.py"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP="$DESKTOP_DIR/debian-trixie-setup.desktop"

if [[ ! -f "$GUI" ]]; then
  echo "No se encontró: $GUI" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 no está instalado." >&2
  exit 1
fi

if ! python3 -c 'import tkinter' >/dev/null 2>&1; then
  echo "Instalando python3-tk..."
  sudo apt update
  sudo apt install -y python3-tk
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Instalando git..."
  sudo apt update
  sudo apt install -y git
fi

mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Debian Trixie Setup
Comment=Configurador gráfico de Debian 13 Trixie
Exec=/usr/bin/python3 $GUI
Icon=system-software-install
Terminal=false
Categories=System;Settings;
StartupNotify=true
EOF

chmod +x "$GUI"
chmod +x "$ROOT/setup/setup-debian-trixie.sh" "$ROOT/cleanup/cleanup-debian-trixie.sh"

echo "Lanzador instalado:"
echo "  $DESKTOP"
echo
echo "Puedes abrir 'Debian Trixie Setup' desde el menú de aplicaciones de KDE."
