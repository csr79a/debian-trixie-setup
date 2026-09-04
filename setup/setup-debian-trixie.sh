#!/usr/bin/env bash
#
# setup-debian-trixie.sh
#
# Script de configuración inicial para Debian 13 (trixie) con KDE Plasma.
# Configura los repositorios oficiales (deb822), actualiza el sistema,
# instala un set de paquetes de desarrollo/multimedia/sistema, el
# microcode correcto según el fabricante de CPU, y añade el remoto de
# Flathub.
#
# Uso:
#   chmod +x setup-debian-trixie.sh
#   ./setup-debian-trixie.sh          # modo interactivo (pide confirmación)
#   ./setup-debian-trixie.sh -y       # modo no interactivo (asume "sí" en todo)
#
# Licencia: MIT

set -euo pipefail

# ----------------------------------------------------------------------
# 0. Opciones de línea de comandos
# ----------------------------------------------------------------------

ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      echo "Uso: $0 [-y|--yes]"
      echo "  -y, --yes   No pedir confirmación (modo no interactivo)."
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

# Pequeño helper para confirmaciones, respeta -y/--yes.
confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  local ans
  read -rp "$prompt [y/N] " ans
  [[ "${ans,,}" == "y" ]]
}

# Con -y también evitamos que apt/debconf se queden esperando input
# (p. ej. avisos de licencia de firmware no libre). OJO: esto silencia
# TODOS los prompts de debconf durante la instalación, no solo los de
# firmware, así que solo se activa en modo no interactivo explícito.
if [[ "$ASSUME_YES" -eq 1 ]]; then
  export DEBIAN_FRONTEND=noninteractive
fi

# ----------------------------------------------------------------------
# 1. Comprobaciones previas
# ----------------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
  echo "No ejecutes este script directamente como root. Usa un usuario normal;" \
       "se te pedirá la contraseña de sudo cuando haga falta." >&2
  exit 1
fi

if ! command -v apt >/dev/null 2>&1; then
  echo "Este script está pensado para sistemas basados en APT (Debian/derivados)." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "No se encontró el comando 'sudo' en este sistema." >&2
  echo "Revisa la sección 'Requisitos previos: dejar sudo listo' del README" \
       "antes de ejecutar este script." >&2
  exit 1
fi

# Comprueba (y cachea) las credenciales de sudo aquí, al principio, en vez
# de dejar que el primer 'sudo tee'/'sudo apt' de más abajo sea quien
# descubra que el usuario no está en el grupo sudo. Si falla, sudo ya
# imprime su propio mensaje de error explicando el motivo.
echo "Comprobando permisos de sudo..."
if ! sudo -v; then
  echo "No se pudieron validar los permisos de sudo. Revisa la sección" \
       "'Requisitos previos: dejar sudo listo' del README." >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${VERSION_CODENAME:-}" != "trixie" ]]; then
    echo "Aviso: este script está probado en Debian trixie (13)." \
         "Se ha detectado: ${PRETTY_NAME:-desconocido}."
    confirm "¿Quieres continuar de todas formas?" || exit 1
  fi
fi

# ----------------------------------------------------------------------
# 2. Repositorios (formato deb822)
# ----------------------------------------------------------------------

SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"

if [[ -f "$SOURCES_FILE" ]]; then
  echo "Ya existe $SOURCES_FILE, no se sobrescribe. Revísalo manualmente si hace falta."
else
  echo "Escribiendo $SOURCES_FILE ..."
  sudo tee "$SOURCES_FILE" >/dev/null <<'EOF'
Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
fi

# Nota para quien publique/use este script: este sources.list activa
# los componentes "contrib", "non-free" y "non-free-firmware" (software
# y firmware no libres). Coméntalo en tu README si te importa.

echo "Actualizando índices de paquetes..."
sudo apt update

# Tras cambiar/crear los repos (o añadir backports) es buena práctica
# actualizar los paquetes ya instalados antes de añadir más, para
# partir de un sistema consistente.
if confirm "¿Quieres hacer 'apt full-upgrade' antes de continuar?"; then
  sudo apt full-upgrade -y
else
  echo "Se omite full-upgrade. Puedes ejecutarlo luego con: sudo apt full-upgrade"
fi

# ----------------------------------------------------------------------
# 3. Detección de CPU para el microcode correcto
# ----------------------------------------------------------------------

CPU_VENDOR="$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $NF}')"

case "$CPU_VENDOR" in
  GenuineIntel)
    MICROCODE_PKG="intel-microcode"
    ;;
  AuthenticAMD)
    MICROCODE_PKG="amd64-microcode"
    ;;
  *)
    echo "Aviso: no se ha podido determinar el fabricante de CPU (vendor_id='$CPU_VENDOR')." \
         "No se instalará ningún paquete de microcode automáticamente."
    MICROCODE_PKG=""
    ;;
esac

if [[ -n "$MICROCODE_PKG" ]]; then
  echo "CPU detectada: $CPU_VENDOR -> se instalará $MICROCODE_PKG"
fi

# ----------------------------------------------------------------------
# 4. Lista de paquetes
# ----------------------------------------------------------------------

PACKAGES=(
  # Control de versiones / descargas
  git git-lfs curl wget

  # Compresión
  unzip zip 7zip

  # Sistema / diagnóstico
  btop fastfetch tree jq
  ripgrep fd-find
  pciutils usbutils lshw dmidecode inxi hwinfo
  lm-sensors acpi

  # Desarrollo / compilación
  build-essential gcc g++ make
  cmake ninja-build pkg-config
  autoconf automake libtool
  openssh-client

  # Multimedia
  ffmpeg
  gstreamer1.0-libav
  gstreamer1.0-plugins-good
  gstreamer1.0-plugins-bad
  gstreamer1.0-plugins-ugly
  pavucontrol

  # Firmware
  # "firmware-linux" es un metapaquete que arrastra TODO el firmware
  # no libre disponible (firmware-linux-nonfree), no solo el de tu
  # hardware. Es cómodo pero pesado. Si prefieres algo más quirúrgico,
  # sustitúyelo por firmware-misc-nonfree + el paquete específico de tu
  # wifi/gpu (p. ej. firmware-iwlwifi, firmware-amd-graphics, etc.),
  # que puedes identificar con: lspci -k
  firmware-linux

  # Gestión de paquetes (interfaz gráfica)
  # Synaptic: gestor de paquetes gráfico completo (buscar, instalar,
  # quitar, marcar como "mantener versión", ver dependencias, etc.).
  # GDebi: instala archivos .deb sueltos (descargados manualmente) con
  # todas sus dependencias, algo que el doble clic no hace por defecto.
  synaptic
  gdebi

  # Flatpak + integración con Discover (KDE Plasma)
  flatpak
  plasma-discover-backend-flatpak
)

# Añade el microcode al final si se ha podido detectar
if [[ -n "$MICROCODE_PKG" ]]; then
  PACKAGES+=("$MICROCODE_PKG")
fi

echo
echo "Se van a instalar los siguientes paquetes:"
printf '  - %s\n' "${PACKAGES[@]}"
echo
confirm "¿Continuar con la instalación?" || { echo "Instalación cancelada por el usuario."; exit 0; }

sudo apt install -y "${PACKAGES[@]}"

# ----------------------------------------------------------------------
# 5. Flathub
# ----------------------------------------------------------------------

if ! flatpak remote-list | grep -q '^flathub'; then
  echo "Añadiendo el remoto de Flathub..."
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
else
  echo "El remoto de Flathub ya está configurado."
fi

# ----------------------------------------------------------------------
# 5b. ZRAM (swap comprimido en RAM, 8 GB fijos)
# ----------------------------------------------------------------------
#
# zram crea un dispositivo de swap comprimido que vive en RAM en vez de
# en disco: es mucho más rápido que el swap tradicional y ayuda a evitar
# que el sistema se quede sin memoria en cargas puntuales. Aquí se fija
# un tamaño ABSOLUTO de 8 GiB (en vez de un porcentaje de la RAM total),
# tal y como se pidió. Es un paso independiente y opcional: se pregunta
# aparte porque toca la configuración de swap del sistema.

ZRAM_SIZE_MB=8192  # 8 GiB, en MiB (unidad que usa zram-tools)

echo
if confirm "¿Configurar un dispositivo zram de 8 GB de swap comprimido en RAM?"; then
  if ! dpkg -s zram-tools >/dev/null 2>&1; then
    echo "Instalando zram-tools..."
    sudo apt install -y zram-tools
  else
    echo "zram-tools ya está instalado."
  fi

  ZRAM_CONF="/etc/default/zramswap"

  if [[ -f "$ZRAM_CONF" ]]; then
    # Copia de seguridad de la config previa, por si acaso.
    ZRAM_BACKUP="${ZRAM_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    sudo cp "$ZRAM_CONF" "$ZRAM_BACKUP"
    echo "Copia de seguridad de la configuración previa: $ZRAM_BACKUP"

    # Distintas versiones de zram-tools llaman a la variable de tamaño
    # fijo "SIZE" o "ALLOCATION" (ambas en MiB). Se detecta cuál usa la
    # versión instalada en vez de asumir un nombre concreto.
    if grep -q '^#\?SIZE=' "$ZRAM_CONF"; then
      SIZE_VAR="SIZE"
    elif grep -q '^#\?ALLOCATION=' "$ZRAM_CONF"; then
      SIZE_VAR="ALLOCATION"
    else
      SIZE_VAR=""
    fi

    if [[ -n "$SIZE_VAR" ]]; then
      # Comenta cualquier variable de porcentaje (PERCENT/PERCENTAGE):
      # si queda activa, tiene prioridad sobre el tamaño fijo y lo ignora.
      sudo sed -i -E 's/^#?(PERCENT|PERCENTAGE)=.*/#&/' "$ZRAM_CONF"

      # Descomenta/fija la variable de tamaño detectada a 8 GiB.
      if grep -q "^${SIZE_VAR}=" "$ZRAM_CONF"; then
        sudo sed -i "s/^${SIZE_VAR}=.*/${SIZE_VAR}=${ZRAM_SIZE_MB}/" "$ZRAM_CONF"
      else
        sudo sed -i "s/^#${SIZE_VAR}=.*/${SIZE_VAR}=${ZRAM_SIZE_MB}/" "$ZRAM_CONF"
      fi

      echo "Configurado ${SIZE_VAR}=${ZRAM_SIZE_MB} (8 GiB) en $ZRAM_CONF"
      sudo systemctl restart zramswap.service 2>/dev/null || sudo service zramswap restart

      echo "Estado actual del zram:"
      zramctl 2>/dev/null || true
      swapon --show 2>/dev/null || true
    else
      echo "Aviso: no se reconoció el formato de $ZRAM_CONF (puede que" \
           "zram-tools use una versión con variables distintas a las" \
           "esperadas). No se modificó el tamaño automáticamente para" \
           "evitar dejar una configuración inconsistente; revísalo a mano:" \
           "https://wiki.debian.org/ZRam"
    fi
  else
    echo "Aviso: no se encontró $ZRAM_CONF tras instalar zram-tools." \
         "Revisa manualmente: https://wiki.debian.org/ZRam"
  fi
else
  echo "Se omite la configuración de zram."
fi

# ----------------------------------------------------------------------
# 6. Notas finales
# ----------------------------------------------------------------------

cat <<'EOF'

Instalación completada.

Notas:
  - fd-find se instala como binario "fdfind", no "fd" (conflicto de
    nombre en Debian). Si lo quieres como "fd":
      mkdir -p ~/.local/bin
      ln -s "$(command -v fdfind)" ~/.local/bin/fd

  - Puede que haga falta reiniciar sesión (o el sistema) para que
    algunos cambios de firmware/microcode surtan efecto.

  - Synaptic y GDebi ya están instalados: Synaptic desde el menú de
    aplicaciones (o "synaptic-pkexec" por terminal); GDebi se puede
    invocar sobre un .deb suelto con: gdebi archivo.deb

  - Si configuraste zram, comprueba su estado cuando quieras con:
      zramswap status
      swapon --show
    Para desactivarlo más adelante:
      sudo systemctl disable --now zramswap
      sudo apt remove zram-tools
    La configuración previa (si existía) quedó respaldada junto a
    /etc/default/zramswap con un sufijo .bak.<fecha>.

  - Si usaste -y, revisa que no se haya omitido ningún aviso importante
    de debconf (se silencian en modo no interactivo).
EOF
