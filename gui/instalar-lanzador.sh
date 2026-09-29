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
    echo "Python 3 no está instalado."
    echo "Instálalo con: sudo apt install python3"
    exit 1
fi

if ! python3 -c 'import PyQt6' >/dev/null 2>&1; then
    echo "Instalando dependencias del GUI Qt..."
    sudo apt update
    sudo apt install -y python3-pyqt6
fi

if ! python3 -c 'import PyQt6, pyte' >/dev/null 2>&1; then
    echo "ERROR: PyQt6 sigue sin estar disponible después de instalar sus dependencias." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Instalando git..."
    sudo apt update
    sudo apt install -y git
fi

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: Git sigue sin estar disponible después de instalarlo." >&2
    exit 1
fi

# Comprobar el GUI antes de crear el lanzador gráfico.
if ! python3 -m py_compile "$GUI"; then
    echo "ERROR: el GUI no supera la comprobación de sintaxis:" >&2
    echo "  $GUI" >&2
    exit 1
fi

mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Debian Trixie Setup
Comment=Configurador gráfico de Debian 13 Trixie
Exec=/usr/bin/python3 "$GUI"
TryExec=/usr/bin/python3
Path=$ROOT
Icon=system-software-install
Terminal=false
Categories=System;Settings;
StartupNotify=true
EOF

chmod +x "$GUI"
chmod +x     "$ROOT/setup/setup-debian-trixie.sh"     "$ROOT/cleanup/cleanup-debian-trixie.sh"     "$ROOT/gaming/setup-gaming-debian-trixie.sh"     "$ROOT/gaming/cleanup-gaming-debian-trixie.sh"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
fi

echo "Lanzador instalado correctamente:"
echo "  $DESKTOP"
echo
echo "Comprobación del GUI: OK"
echo "Dependencias: PyQt6"
echo "Puedes abrir 'Debian Trixie Setup' desde el menú de aplicaciones de KDE."
echo "Los instaladores se ejecutan en el terminal integrado de la propia ventana."
