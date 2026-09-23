#!/usr/bin/env bash
#
# setup-debian-trixie.sh — Configurador de Debian Trixie csr79a
#
# Script de configuración inicial para Debian 13 (trixie) con KDE Plasma.
# Configura los repositorios oficiales (deb822), actualiza el sistema,
# instala por bloques un set de paquetes de desarrollo/multimedia/sistema
# (con tolerancia a fallos por bloque), el microcode correcto según el
# fabricante de CPU, fuentes de Windows y de Ubuntu, añade el remoto de
# Flathub, y ofrece (opcional, tras detectar el hardware) zram, Firefox
# de Mozilla, el driver NVIDIA y switcheroo-control si hay GPU híbrida.
#
# Interfaz por pantallas (whiptail) para bienvenida, decisiones y resumen
# final; el progreso de comandos largos (apt, sed, etc.) se muestra como
# texto normal de terminal.
#
# Uso:
#   chmod +x setup-debian-trixie.sh
#   ./setup-debian-trixie.sh          # modo interactivo (pide confirmación)
#   ./setup-debian-trixie.sh -y       # modo no interactivo (asume "sí" en todo,
#                                      # incluidas operaciones destructivas; ver --help)
#
# Historial de versiones:
#   1.3.0 - Paridad con setup-debian-sid.sh en dos decisiones que se habían
#           dejado pendientes en la 1.2.0:
#           * Se quita "gdebi" del grupo "Gestión de paquetes (GUI)"
#             (queda solo "synaptic"), igual que en la versión de sid.
#           * Se añade el grupo "Utilidades de disco" (gnome-disk-utility),
#             que faltaba respecto a sid. Es también el motivo por el que
#             cleanup-debian-trixie.sh puede ofrecer, sin más aviso,
#             quitar KDE Partition Manager con una alternativa gráfica ya
#             instalada.
#   1.2.0 - Hardening general portado desde setup-debian-sid.sh:
#           * Los paquetes se instalan agrupados en bloques temáticos, cada
#             uno con su propio "apt install"; si un bloque falla (paquete
#             roto/en tránsito), se avisa y se continúa con el resto en vez
#             de abortar todo el script (antes, un único "apt install"
#             gigante hacía fallar toda la instalación por un solo paquete).
#           * Fallback automático de "7zip" a "p7zip-full" si el primero no
#             está disponible en el repo.
#           * Nueva función ensure_cmd(): reintenta instalar el paquete de
#             un comando que falte (wget, lspci) en vez de asumir que ya
#             está, y omite con aviso el paso que lo necesite si no se
#             consigue.
#           * Firefox: cambia el orden de la sustitución. Ahora se instala
#             primero Firefox de Mozilla y solo si eso sale bien se purga
#             Firefox ESR; si el usuario lo confirma, se borra por completo
#             ~/.mozilla/firefox (ya no se usa la función quirúrgica
#             _cleanup_profiles_ini de la 1.1.0, que se retira). Es un
#             cambio de comportamiento deliberado: más simple y robusto,
#             pero ya no se intenta conservar el perfil antiguo.
#           * Se añade la instalación opcional de fuentes de Windows
#             (ttf-mscorefonts-installer, acepta EULA automáticamente con
#             -y) y de fuentes de Ubuntu (fonts-ubuntu).
#           * NVIDIA: se añade un fichero de pines de prioridad para que
#             todo el stack nvidia-*/libnvidia-* (64 y 32 bits) se resuelva
#             siempre desde el repo CUDA de NVIDIA y no se mezcle con
#             paquetes nativos de Debian; se instalan también las librerías
#             de 32 bits (para Steam/Proton) y nvidia-vaapi-driver
#             (aceleración de vídeo en navegadores); detección de Secure
#             Boot más robusta (mokutil + fallback a variable EFI); si
#             falla la instalación del driver, no se toca nouveau ni GRUB.
#           * switcheroo-control: se rastrea el éxito/fallo de instalación
#             y activación en vez de asumir que todo va a salir bien.
#           * El resumen final ahora reporta explícitamente cada fallo
#             parcial ocurrido durante la ejecución (full-upgrade, purga de
#             ESR, instalación de Firefox, bloques de paquetes fallidos),
#             en vez de asumir que todo lo que no abortó el script salió
#             bien.
#           * -y ahora avisa en pantalla, al arrancar, de qué operaciones
#             destructivas va a aceptar automáticamente; --help las detalla.
#           * NO se ha portado la instalación de paquetes de Tesseract OCR
#             de la versión Sid: esa opción existe porque Sid (rolling) ya
#             trae Plasma 6.6+, donde Spectacle añadió la extracción de
#             texto de capturas. Debian trixie es stable y se queda fijo en
#             Plasma 6.3.x durante todo su ciclo de vida (no recibe subidas
#             de versión mayor de Plasma por actualizaciones normales), así
#             que esos paquetes no activarían ninguna función en Spectacle
#             aquí. Si en el futuro trixie-backports ofreciera una versión
#             de Plasma con esa función, revisa si merece la pena añadirlo.
#   1.1.0 - Sustitución de Firefox ESR reforzada (portado desde
#           setup-debian-sid.sh): se usa "apt purge" en vez de "remove"
#           (evita restos de config en estado "rc"), se limpia
#           /etc/firefox-esr a mano (dpkg no lo borra si queda algo
#           ajeno dentro), y se toma una foto de las carpetas de perfil
#           existentes ANTES de tocar nada (en ese punto solo pueden
#           ser de ESR, tengan o no "esr" en el nombre) para poder
#           ofrecer, tras instalar Firefox release, migrar/eliminar el
#           perfil antiguo y limpiar profiles.ini con la nueva función
#           _cleanup_profiles_ini. NOTA: esta función se retira en 1.2.0.
#   1.0.0 - Versión base.
#
# Licencia: MIT

set -euo pipefail

TITLE="Configurador de Debian Trixie csr79a"
VERSION="1.3.0"

log()   { echo -e "\e[1;34m[*]\e[0m $*"; }
ok()    { echo -e "\e[1;32m[OK]\e[0m $*"; }
warn()  { echo -e "\e[1;33m[!]\e[0m $*"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

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
      cat <<EOF
Uso: $0 [-y|--yes] [-h|--help]

  -y, --yes   Modo no interactivo (sin pantallas): acepta automáticamente TODAS
              las preguntas del script, incluidas operaciones destructivas:
                - comentar el contenido activo de /etc/apt/sources.list (con
                  copia de seguridad previa);
                - eliminar Firefox ESR, su configuración (/etc/firefox-esr) y
                  TODOS sus perfiles y datos (~/.mozilla/firefox), de forma
                  irreversible;
                - modificar GRUB, initramfs y otras configuraciones del sistema
                  (NVIDIA, zram, sysctl...).

  -h, --help  Muestra esta ayuda.
EOF
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

# Pequeño helper para confirmaciones. En modo -y no se muestra ninguna
# pantalla (whiptail se salta por completo); en modo interactivo, cada
# decisión se muestra como una pantalla whiptail --yesno, que ya
# devuelve 0 (Sí) / 1 (No) directamente utilizable en un "if confirm...".
confirm() {
  local prompt="$1"
  local height="${2:-14}"
  local width="${3:-70}"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  whiptail --title "$TITLE" --yesno "$prompt" "$height" "$width"
}

# Con -y también evitamos que apt/debconf se queden esperando input
# (p. ej. avisos de licencia de firmware/fuentes no libres). OJO: esto
# silencia TODOS los prompts de debconf durante la instalación, no solo
# los de firmware, así que solo se activa en modo no interactivo
# explícito.
if [[ "$ASSUME_YES" -eq 1 ]]; then
  export DEBIAN_FRONTEND=noninteractive
  warn "MODO -y ACTIVO: se aceptarán automáticamente TODAS las preguntas, incluidas operaciones destructivas:"
  warn "  - comentar el contenido activo de /etc/apt/sources.list (con copia de seguridad);"
  warn "  - eliminar Firefox ESR, /etc/firefox-esr y TODOS los perfiles y datos de ESR (irreversible);"
  warn "  - modificar GRUB, initramfs y otras configuraciones del sistema (NVIDIA, zram, sysctl)."
fi

# ----------------------------------------------------------------------
# 1. Comprobaciones previas
# ----------------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
  error "No ejecutes este script directamente como root. Usa un usuario normal; se te pedirá la contraseña de sudo cuando haga falta."
fi

if ! command -v apt >/dev/null 2>&1; then
  error "Este script está pensado para sistemas basados en APT (Debian/derivados)."
fi

if ! command -v sudo >/dev/null 2>&1; then
  error "No se encontró el comando 'sudo' en este sistema. Revisa la sección 'Requisitos previos: dejar sudo listo' del README antes de ejecutar este script."
fi

# whiptail hace falta para las pantallas de este propio script; si no
# está (Debian mínimo sin tareas de escritorio), se instala antes de
# mostrar nada.
if ! command -v whiptail >/dev/null 2>&1; then
  log "Instalando whiptail (necesario para las pantallas de este instalador)..."
  sudo apt update
  sudo apt install -y whiptail
fi

log "Comprobando permisos de sudo..."
if ! sudo -v; then
  error "No se pudieron validar los permisos de sudo. Revisa la sección 'Requisitos previos: dejar sudo listo' del README."
fi

# ----------------------------------------------------------------------
# Detección de CPU (fabricante -> microcode; modelo -> solo informativo)
# ----------------------------------------------------------------------

CPU_VENDOR="$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $NF}' || true)"
CPU_MODEL_NAME="$(grep -m1 'model name' /proc/cpuinfo | sed 's/^.*: //' || true)"
CPU_MODEL_NAME="${CPU_MODEL_NAME:-desconocido}"

case "$CPU_VENDOR" in
  GenuineIntel)
    MICROCODE_PKG="intel-microcode"
    ;;
  AuthenticAMD)
    MICROCODE_PKG="amd64-microcode"
    ;;
  *)
    warn "No se ha podido determinar el fabricante de CPU (vendor_id='$CPU_VENDOR'). No se instalará ningún paquete de microcode automáticamente."
    MICROCODE_PKG=""
    ;;
esac

# NOTA: Debian solo distribuye microcode genérico por fabricante
# (intel-microcode / amd64-microcode), no hay paquetes específicos por
# modelo de CPU. Por eso el modelo detectado aquí (CPU_MODEL_NAME) es
# puramente informativo: se muestra en pantalla, pero no cambia qué
# paquete se instala.

# ----------------------------------------------------------------------
# Pantalla de bienvenida
# ----------------------------------------------------------------------

confirm "Versión del Configurador de Debian Trixie csr79a ${VERSION}\n\nEste programa configura los repositorios oficiales, actualiza el sistema, instala por bloques un set de paquetes de desarrollo/multimedia/sistema, fuentes de Windows y de Ubuntu, y ofrece de forma opcional zram, Firefox de Mozilla, driver NVIDIA y switcheroo-control según el hardware detectado.\n\nCPU detectada: ${CPU_MODEL_NAME}\n\n¿Desea continuar?" 18 76 || exit 0

DETECTED_CODENAME=""
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  DETECTED_CODENAME="${VERSION_CODENAME:-}"
  if [[ "$DETECTED_CODENAME" != "trixie" ]]; then
    confirm "Aviso: este script está probado en Debian trixie (13).\n\nSe ha detectado: ${PRETTY_NAME:-desconocido}.\n\n¿Quieres continuar de todas formas?" || exit 1
  fi
fi

# ----------------------------------------------------------------------
# 2. Repositorios (formato deb822)
# ----------------------------------------------------------------------

LEGACY_SOURCES="/etc/apt/sources.list"
SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"

# El instalador de Debian (sobre todo desde la ISO oficial con DVD) suele
# dejar un /etc/apt/sources.list "clásico" ya poblado (incluida a veces una
# entrada de CD-ROM). Si lo dejamos tal cual y además escribimos nuestro
# propio debian.sources (deb822) con las mismas suites/componentes, apt
# acaba con los repos definidos por duplicado y falla al intentar
# actualizar el CD-ROM. Para evitarlo, si ese archivo tiene líneas activas
# (no comentarios ni vacías), se hace una copia de seguridad y se comentan
# todas, dejando que sea únicamente debian.sources quien defina los repos.
if [[ -f "$LEGACY_SOURCES" ]] && grep -qE '^\s*deb(-src)?\s' "$LEGACY_SOURCES"; then
  if confirm "Se ha detectado contenido activo en $LEGACY_SOURCES (típico de una instalación desde la ISO oficial, a veces con una entrada de CD-ROM).\n\nPara evitar repositorios duplicados, se comentará su contenido, dejando que $SOURCES_FILE (creado a continuación) sea la única fuente de los repos oficiales de Debian.\n\n¿Continuar? (se guarda una copia de seguridad antes de tocar nada)" 16 76; then
    LEGACY_BACKUP="${LEGACY_SOURCES}.bak.$(date +%Y%m%d%H%M%S)"
    sudo cp "$LEGACY_SOURCES" "$LEGACY_BACKUP"
    ok "Copia de seguridad: $LEGACY_BACKUP"
    sudo sed -i -E '/^\s*deb(-src)?\s/ s/^/# desactivado por setup-debian-trixie.sh -- /' "$LEGACY_SOURCES"
    ok "Contenido de $LEGACY_SOURCES comentado."
  else
    warn "Se omite la limpieza de $LEGACY_SOURCES. Es probable que 'apt update' muestre avisos de repos duplicados o falle en la entrada de CD-ROM."
  fi
fi

if [[ -f "$SOURCES_FILE" ]]; then
  warn "Ya existe $SOURCES_FILE, no se sobrescribe. Revísalo manualmente si hace falta."
else
  log "Escribiendo $SOURCES_FILE ..."
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
  ok "$SOURCES_FILE escrito."
fi

# Nota para quien publique/use este script: este sources.list activa
# los componentes "contrib", "non-free" y "non-free-firmware" (software
# y firmware no libres). Coméntalo en tu README si te importa.

log "Actualizando índices de paquetes..."
if ! sudo apt update; then
  warn "'apt update' terminó con errores (puede ser un repositorio concreto o la red). Se continúa con los índices disponibles."
fi

# Tras cambiar/crear los repos (o añadir backports) es buena práctica
# actualizar los paquetes ya instalados antes de añadir más, para
# partir de un sistema consistente.
FULL_UPGRADE_FAILED=0
if confirm "¿Quieres hacer 'apt full-upgrade' antes de continuar?"; then
  if sudo apt full-upgrade -y; then
    ok "apt full-upgrade completado."
  else
    FULL_UPGRADE_FAILED=1
    warn "'apt full-upgrade' ha fallado."
    # Solo se continúa si dpkg no ha quedado en un estado inconsistente:
    # instalar paquetes o compilar módulos DKMS sobre un sistema a medio
    # actualizar podría empeorarlo.
    DPKG_AUDIT="$(sudo dpkg --audit 2>&1 || true)"
    if [[ -n "$DPKG_AUDIT" ]]; then
      warn "dpkg ha detectado paquetes en un estado inconsistente:"
      echo "$DPKG_AUDIT"
      error "No es seguro continuar. Resuelve el problema (por ejemplo con 'sudo dpkg --configure -a' y 'sudo apt -f install') y vuelve a ejecutar el script."
    fi
    warn "dpkg está consistente: se continúa con el resto del script. Al terminar, resuelve y reintenta: sudo apt update && sudo apt full-upgrade"
  fi
else
  warn "Se omite full-upgrade. Puedes ejecutarlo luego con: sudo apt full-upgrade"
fi

if [[ -n "$MICROCODE_PKG" ]]; then
  ok "CPU detectada: ${CPU_MODEL_NAME} (${CPU_VENDOR}) -> se instalará $MICROCODE_PKG"
fi

# ----------------------------------------------------------------------
# 3. Lista de paquetes
# ----------------------------------------------------------------------
#
# Se instalan agrupados en bloques temáticos, cada uno con su propio
# "apt install", en vez de un único comando con todos los paquetes juntos.
# Con "set -e" activo, un solo paquete roto/en tránsito haría abortar TODO
# el script de golpe -- y a estas alturas ya se cambiaron/confirmaron los
# repos y se pudo correr full-upgrade, así que un aborto total dejaría el
# sistema a mitad de camino sin fuentes/Flathub/zram/Firefox/NVIDIA. Al
# instalar por grupos con su propia comprobación de resultado, un fallo
# puntual solo omite ESE grupo (se avisa cuál y con qué paquetes) y el
# resto de la instalación sigue igual.

if apt-cache show 7zip >/dev/null 2>&1; then
  ARCHIVE_PACKAGES=(unzip zip 7zip)
else
  warn "El paquete '7zip' no está disponible en tus repos; se usará 'p7zip-full' en su lugar."
  ARCHIVE_PACKAGES=(unzip zip p7zip-full)
fi

# Dos arrays paralelos (los índices deben corresponderse 1 a 1): nombre
# descriptivo del grupo y string con sus paquetes separados por espacio.
GROUP_NAMES=(
  "Control de versiones / descargas"
  "Compresión"
  "Sistema / diagnóstico"
  "Desarrollo / compilación"
  "Multimedia"
  "Firmware"
  "Gestión de paquetes (GUI)"
  "Flatpak + integración con Discover"
  "Utilidades de disco"
)

GROUP_PACKAGES=(
  "git git-lfs curl wget"
  "${ARCHIVE_PACKAGES[*]}"
  "btop fastfetch tree jq ripgrep fd-find pciutils usbutils lshw dmidecode inxi hwinfo lm-sensors acpi"
  "build-essential gcc g++ make cmake ninja-build pkg-config autoconf automake libtool openssh-client"
  "ffmpeg gstreamer1.0-libav gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly pavucontrol"
  # "firmware-linux" es un metapaquete que arrastra TODO el firmware no
  # libre disponible (firmware-linux-nonfree), no solo el de tu hardware.
  # Es cómodo pero pesado. Si prefieres algo más quirúrgico, sustitúyelo
  # por firmware-misc-nonfree + el paquete específico de tu wifi/gpu
  # (p. ej. firmware-iwlwifi, firmware-amd-graphics, etc.), que puedes
  # identificar con: lspci -k
  "firmware-linux"
  # Synaptic: gestor de paquetes gráfico completo (buscar, instalar,
  # quitar, marcar como "mantener versión", ver dependencias, etc.).
  "synaptic"
  "flatpak plasma-discover-backend-flatpak"
  # Utilidad gráfica para gestionar discos y particiones (crear/borrar/
  # redimensionar particiones, formatear, comprobar SMART...). Es la
  # alternativa que asume cleanup-debian-trixie.sh si en algún momento
  # decides quitar KDE Partition Manager.
  "gnome-disk-utility"
)

if [[ -n "$MICROCODE_PKG" ]]; then
  GROUP_NAMES+=("Microcode de CPU")
  GROUP_PACKAGES+=("$MICROCODE_PKG")
fi

# Solo para mostrar el listado completo al usuario antes de confirmar.
ALL_PACKAGES=()
for pkgs in "${GROUP_PACKAGES[@]}"; do
  # shellcheck disable=SC2206
  ALL_PACKAGES+=($pkgs)
done

echo
echo "Se van a instalar los siguientes paquetes (agrupados en ${#GROUP_NAMES[@]} bloques):"
printf '  - %s\n' "${ALL_PACKAGES[@]}"
echo
confirm "Se van a instalar ${#ALL_PACKAGES[@]} paquetes (desarrollo, multimedia, sistema), en ${#GROUP_NAMES[@]} bloques independientes. Si alguno falla, se avisa y se continúa con el resto en vez de abortar toda la instalación.\n\n¿Continuar con la instalación?" || { warn "Instalación cancelada por el usuario."; exit 0; }

FAILED_GROUPS=()
for i in "${!GROUP_NAMES[@]}"; do
  group_name="${GROUP_NAMES[$i]}"
  # shellcheck disable=SC2206
  group_pkgs=(${GROUP_PACKAGES[$i]})
  log "Instalando (${group_name}): ${group_pkgs[*]}"
  if sudo apt install -y "${group_pkgs[@]}"; then
    ok "${group_name}: instalado correctamente."
  else
    warn "${group_name}: FALLÓ la instalación de este grupo (${group_pkgs[*]})."
    warn "Se continúa con el resto del script; puedes reintentar este grupo a mano luego con: sudo apt install ${group_pkgs[*]}"
    FAILED_GROUPS+=("$group_name")
  fi
done

if [[ ${#FAILED_GROUPS[@]} -gt 0 ]]; then
  warn "Grupos que fallaron y se omitieron: ${FAILED_GROUPS[*]}"
  warn "El resto de los pasos continúa. Los que necesitan un paquete de un grupo fallido (wget, flatpak, lspci) lo reintentan o se omiten con aviso."
fi

# ----------------------------------------------------------------------
# 3b. Prerrequisitos de los pasos siguientes
# ----------------------------------------------------------------------
#
# Firefox y NVIDIA usan wget (grupo "Control de versiones / descargas") y
# la detección de GPU usa lspci (pciutils, grupo "Sistema / diagnóstico").
# Si ese grupo falló, se reintenta instalar solo lo imprescindible; si aun
# así no está disponible, el paso que lo necesite se omite con un aviso en
# vez de abortar el script entero por "set -e".

# ensure_cmd <comando> <paquete>: devuelve 0 si el comando existe (o se ha
# podido instalar) y 1 si no.
ensure_cmd() {
  local cmd="$1" pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  warn "No se encontró '$cmd'; se intenta instalar '$pkg'..."
  if sudo apt install -y "$pkg" && command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  warn "No se pudo instalar '$pkg'."
  return 1
}

WGET_OK=0
if ensure_cmd wget wget; then
  WGET_OK=1
fi

# ----------------------------------------------------------------------
# 4. Fuentes de Windows y de Ubuntu (opcional)
# ----------------------------------------------------------------------
#
# Fuentes de Windows: ttf-mscorefonts-installer (Arial, Times New Roman,
# Courier New, etc.). Vive en el componente "contrib" (ya activado en
# nuestro sources.list) porque el propio paquete descarga los .ttf
# originales de Microsoft en tiempo de instalación y requiere aceptar
# su EULA. En modo -y (DEBIAN_FRONTEND=noninteractive) debconf acepta la
# licencia automáticamente vía preseed; en modo interactivo, debconf
# puede mostrar su propia pantalla de aceptación durante el "apt install".
#
# Fuentes de Ubuntu: fonts-ubuntu, ya empaquetada tal cual en los repos
# oficiales de Debian, sin pasos adicionales.

if confirm "¿Instalar fuentes de Windows (Arial, Times New Roman, Courier New...) vía ttf-mscorefonts-installer?\n\nEste paquete descarga las fuentes originales de Microsoft y requiere aceptar su licencia (EULA). En modo no interactivo (-y) se acepta automáticamente." 16 76; then
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | sudo debconf-set-selections
  fi
  if sudo apt install -y ttf-mscorefonts-installer; then
    ok "Fuentes de Windows instaladas."
  else
    warn "No se pudieron instalar las fuentes de Windows (el paquete las descarga de servidores externos, que a veces fallan). Se continúa; reintenta luego con: sudo apt install ttf-mscorefonts-installer"
  fi
else
  warn "Se omiten las fuentes de Windows."
fi

if confirm "¿Instalar las fuentes de Ubuntu (fonts-ubuntu)?"; then
  if sudo apt install -y fonts-ubuntu; then
    ok "Fuentes de Ubuntu instaladas."
  else
    warn "No se pudieron instalar las fuentes de Ubuntu. Se continúa; reintenta luego con: sudo apt install fonts-ubuntu"
  fi
else
  warn "Se omiten las fuentes de Ubuntu."
fi

# ----------------------------------------------------------------------
# 5. Flathub
# ----------------------------------------------------------------------

if command -v flatpak >/dev/null 2>&1; then
  FLATPAK_REMOTES="$(flatpak remote-list --columns=name 2>/dev/null || true)"
  if ! grep -qx 'flathub' <<<"$FLATPAK_REMOTES"; then
    log "Añadiendo el remoto de Flathub..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ok "Remoto de Flathub añadido."
  else
    ok "El remoto de Flathub ya está configurado."
  fi
else
  warn "Flatpak no está instalado (el grupo 'Flatpak + integración con Discover' no se instaló); se omite la configuración de Flathub."
fi

# ----------------------------------------------------------------------
# 6. ZRAM (swap comprimido en RAM, tamaño automático según RAM total)
# ----------------------------------------------------------------------
#
# zram crea un dispositivo de swap comprimido que vive en RAM en vez de
# en disco: es mucho más rápido que el swap tradicional y ayuda a evitar
# que el sistema se quede sin memoria en cargas puntuales. El tamaño se
# calcula automáticamente como la mitad de la RAM total del sistema
# (regla práctica habitual): 8 GB de RAM -> 4 GB de zram, 16 GB -> 8 GB,
# 32 GB -> 16 GB, etc. Se detecta en tiempo de ejecución a partir de
# /proc/meminfo, así que el script se adapta a la máquina donde se
# ejecute sin necesidad de tocar nada a mano. Es un paso independiente y
# opcional: se pregunta aparte porque toca la configuración de swap del
# sistema.

TOTAL_RAM_KB="$(grep -m1 '^MemTotal:' /proc/meminfo | awk '{print $2}')"
TOTAL_RAM_MB=$(( TOTAL_RAM_KB / 1024 ))
ZRAM_SIZE_MB=$(( TOTAL_RAM_MB / 2 ))

# Salvaguarda: si por lo que sea no se pudo leer /proc/meminfo o el
# cálculo da 0, no se propone zram en vez de configurar un tamaño inválido.
if [[ -z "$TOTAL_RAM_KB" || "$ZRAM_SIZE_MB" -le 0 ]]; then
  warn "No se ha podido determinar la RAM total del sistema; se omite la configuración de zram."
else
  if confirm "RAM total detectada: ${TOTAL_RAM_MB} MiB.\n\n¿Configurar zram (swap comprimido en RAM) con ${ZRAM_SIZE_MB} MiB (mitad de la RAM)?" 14 70; then
    ZRAM_TOOLS_OK=1
    if ! dpkg -s zram-tools >/dev/null 2>&1; then
      log "Instalando zram-tools..."
      if ! sudo apt install -y zram-tools; then
        ZRAM_TOOLS_OK=0
      fi
    else
      ok "zram-tools ya está instalado."
    fi

    ZRAM_CONF="/etc/default/zramswap"

    if [[ "$ZRAM_TOOLS_OK" -ne 1 ]]; then
      warn "No se pudo instalar zram-tools; se omite la configuración de zram. Reintenta luego con: sudo apt install zram-tools"
    elif [[ -f "$ZRAM_CONF" ]]; then
      # Copia de seguridad de la config previa, por si acaso.
      ZRAM_BACKUP="${ZRAM_CONF}.bak.$(date +%Y%m%d%H%M%S)"
      sudo cp "$ZRAM_CONF" "$ZRAM_BACKUP"
      ok "Copia de seguridad de la configuración previa: $ZRAM_BACKUP"

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
        sudo sed -i -E "/^(PERCENT|PERCENTAGE)=/ s/^/#/" "$ZRAM_CONF"

        # Descomenta/fija la variable de tamaño detectada al valor calculado.
        if grep -q "^${SIZE_VAR}=" "$ZRAM_CONF"; then
          sudo sed -i "s/^${SIZE_VAR}=.*/${SIZE_VAR}=${ZRAM_SIZE_MB}/" "$ZRAM_CONF"
        else
          sudo sed -i "s/^#${SIZE_VAR}=.*/${SIZE_VAR}=${ZRAM_SIZE_MB}/" "$ZRAM_CONF"
        fi

        ok "Configurado ${SIZE_VAR}=${ZRAM_SIZE_MB} (${ZRAM_SIZE_MB} MiB) en $ZRAM_CONF"
        sudo systemctl restart zramswap.service 2>/dev/null || sudo service zramswap restart \
          || warn "No se pudo reiniciar zramswap; la nueva configuración se aplicará tras reiniciar."

        log "Estado actual del zram:"
        zramctl 2>/dev/null || true
        swapon --show 2>/dev/null || true

        # vm.swappiness=60 (valor por defecto) está pensado para swap en
        # disco: el kernel espera a que la RAM esté casi llena antes de
        # usarlo, porque mover datos a disco es lento. Con zram, el swap
        # vive comprimido en RAM (mucho más rápido que un disco), así que
        # conviene un swappiness más alto (rango habitual recomendado con
        # zram: 130-180) para que el kernel mande antes las páginas frías
        # al zram y deje más RAM libre real para caché y procesos activos.
        SWAPPINESS_VALUE=130
        SWAPPINESS_CONF="/etc/sysctl.d/99-zram-swappiness.conf"

        if confirm "¿Ajustar vm.swappiness a ${SWAPPINESS_VALUE} (recomendado con zram, por defecto es 60 y está pensado para swap en disco)?"; then
          echo "vm.swappiness=${SWAPPINESS_VALUE}" | sudo tee "$SWAPPINESS_CONF" >/dev/null
          if sudo sysctl -p "$SWAPPINESS_CONF" >/dev/null; then
            ok "Configurado vm.swappiness=${SWAPPINESS_VALUE} de forma persistente en $SWAPPINESS_CONF"
            ok "Valor activo confirmado: $(sudo sysctl -n vm.swappiness)"
          else
            warn "No se pudo aplicar vm.swappiness ahora; el valor quedó guardado en $SWAPPINESS_CONF y se aplicará al reiniciar."
          fi
        else
          warn "Se omite el ajuste de vm.swappiness (se queda en el valor actual del sistema)."
        fi
      else
        warn "No se reconoció el formato de $ZRAM_CONF (puede que zram-tools use una versión con variables distintas a las esperadas). No se modificó el tamaño automáticamente para evitar dejar una configuración inconsistente; revísalo a mano: https://wiki.debian.org/ZRam"
      fi
    else
      warn "No se encontró $ZRAM_CONF tras instalar zram-tools. Revisa manualmente: https://wiki.debian.org/ZRam"
    fi
  else
    warn "Se omite la configuración de zram."
  fi
fi

# ----------------------------------------------------------------------
# 7. Firefox oficial de Mozilla (sustituye a Firefox ESR, opcional)
# ----------------------------------------------------------------------
#
# Debian, por motivos de licencia de marca, no distribuye "Firefox" tal
# cual: en su lugar trae "firefox-esr" (versión de soporte extendido,
# de actualización más lenta). Este paso, opcional, lo sustituye por el
# Firefox oficial de Mozilla (release normal), siguiendo el
# procedimiento que publica Mozilla para paquetes .deb vía su propio
# repositorio APT: https://support.mozilla.org/kb/install-firefox-linux
#
# Adaptado respecto a la guía original de Mozilla:
#   - Se omite todo lo específico de Ubuntu/snap (no aplica en Debian).
#   - Se elige automáticamente el formato de fichero de repositorio
#     correcto: deb822 (mozilla.sources) para trixie y posteriores, o
#     el formato clásico de una línea (mozilla.list) para codenames
#     anteriores (p. ej. bookworm), por si se ejecuta ahí bajo tu
#     propio riesgo tras el aviso de compatibilidad de la sección 1.
#   - Se verifica la huella digital de la clave de firma antes de
#     confiar en ella; si no coincide, se aborta este paso sin tocar
#     nada más (no se añade el repositorio ni se instala nada).
#
# NOTA sobre el orden (cambiado en la 1.2.0, portado desde
# setup-debian-sid.sh): el objetivo es quedarse SOLO con Firefox de
# Mozilla, sin conservar nada de ESR (paquete, configuración ni
# perfiles). El orden es deliberado:
#   1) se descarga y verifica la clave de Mozilla, se añade su repositorio
#      y se comprueba que está disponible (pasos no destructivos);
#   2) solo si todo eso sale bien se elimina ESR con todos sus datos;
#   3) por último se instala Firefox.
# Así, un fallo de red o de verificación no deja el equipo sin navegador
# ni sin perfil.
#
# AVISO: a diferencia de la 1.1.0 (que usaba _cleanup_profiles_ini para
# intentar conservar el perfil antiguo), aquí se elimina por completo
# ~/.mozilla/firefox si el usuario confirma la sustitución y la purga de
# ESR sale bien. Es irreversible: marcadores, contraseñas, historial y
# extensiones del perfil antiguo se pierden. Firefox normal arranca con
# un perfil limpio desde cero.

MOZILLA_PROFILES_DIR="$HOME/.mozilla/firefox"
ESR_PROFILES_REMOVED=0
ESR_PURGE_FAILED=0
FIREFOX_INSTALL_FAILED=0

if [[ "$WGET_OK" -ne 1 ]]; then
  warn "Falta 'wget' (necesario para descargar la clave de Mozilla) y no se pudo instalar. Se omite la sustitución de Firefox."
elif confirm "¿Sustituir Firefox ESR de Debian por Firefox oficial del repositorio de Mozilla?\n\nAVISO: si Firefox ESR está instalado, se eliminarán también su configuración (/etc/firefox-esr) y TODOS sus perfiles y datos en ~/.mozilla/firefox (marcadores, contraseñas, historial, extensiones). Es irreversible. Firefox normal empezará con un perfil limpio." 18 76; then

  FIREFOX_ESR_PKGS=()
  for pkg in firefox-esr firefox-esr-l10n-es; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      FIREFOX_ESR_PKGS+=("$pkg")
    fi
  done

  MOZILLA_KEY_OK=0
  MOZILLA_READY=0

  # --- 1) Clave de Mozilla: descarga y verificación de la huella ---
  if ! command -v gpg >/dev/null 2>&1; then
    log "Instalando gnupg (necesario para verificar la clave de Mozilla)..."
    sudo apt install -y gnupg || warn "No se pudo instalar gnupg."
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    warn "Sin 'gpg' no se puede verificar la clave de Mozilla. Se omite la sustitución de Firefox; ESR y sus perfiles no se han tocado."
  else
    sudo install -d -m 0755 /etc/apt/keyrings
    if wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
        | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null; then

      # Se usa un GNUPGHOME temporal y aislado en vez del ~/.gnupg del
      # usuario: así no depende de que ya exista (en un usuario que nunca
      # ha usado gpg, gpg no lo crea solo y falla con "no existe el
      # fichero o el directorio"), y de paso no se toca el keyring
      # personal del usuario solo para comprobar una huella digital. Se
      # limpia el directorio al terminar, pase lo que pase (trap).
      MOZILLA_GPG_TMPHOME="$(mktemp -d)"
      trap 'rm -rf "$MOZILLA_GPG_TMPHOME"' EXIT

      MOZILLA_EXPECTED_FPR="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
      MOZILLA_ACTUAL_FPR="$(
        GNUPGHOME="$MOZILLA_GPG_TMPHOME" gpg -n -q --import --import-options import-show \
          /etc/apt/keyrings/packages.mozilla.org.asc \
          | awk '/pub/{getline; gsub(/^ +| +$/,""); print; exit}'
      )" || true

      rm -rf "$MOZILLA_GPG_TMPHOME"
      trap - EXIT

      if [[ "$MOZILLA_ACTUAL_FPR" == "$MOZILLA_EXPECTED_FPR" ]]; then
        ok "Huella digital de la clave de Mozilla verificada correctamente."
        MOZILLA_KEY_OK=1
      else
        warn "ERROR: la huella digital de la clave de Mozilla NO coincide."
        warn "  Esperada: $MOZILLA_EXPECTED_FPR"
        warn "  Obtenida: ${MOZILLA_ACTUAL_FPR:-<vacía>}"
        warn "Por seguridad, se aborta este paso. Firefox ESR y sus perfiles no se han tocado."
        sudo rm -f /etc/apt/keyrings/packages.mozilla.org.asc
      fi
    else
      warn "No se pudo descargar la clave de Mozilla (¿sin conexión?). Se omite la sustitución de Firefox; ESR y sus perfiles no se han tocado."
      sudo rm -f /etc/apt/keyrings/packages.mozilla.org.asc
    fi
  fi

  # --- 2) Repositorio de Mozilla: formato según el codename detectado en
  # la sección 1 (trixie/posteriores usan deb822; codenames anteriores,
  # el formato clásico de una línea) ---
  if [[ "$MOZILLA_KEY_OK" -eq 1 ]]; then
    if [[ "${VERSION_CODENAME:-trixie}" == "bookworm" || "${VERSION_CODENAME:-trixie}" == "bullseye" ]]; then
      MOZILLA_LIST="/etc/apt/sources.list.d/mozilla.list"
      echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        | sudo tee "$MOZILLA_LIST" >/dev/null
      ok "Repositorio de Mozilla escrito en $MOZILLA_LIST (formato clásico)."
    else
      MOZILLA_SOURCES="/etc/apt/sources.list.d/mozilla.sources"
      sudo tee "$MOZILLA_SOURCES" >/dev/null <<'EOF'
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
      ok "Repositorio de Mozilla escrito en $MOZILLA_SOURCES (formato deb822)."
    fi

    # Prioridad para que los paquetes de Mozilla no se vean eclipsados
    # por otro repo que también publique "firefox".
    sudo tee /etc/apt/preferences.d/mozilla >/dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    if ! sudo apt update; then
      warn "'apt update' terminó con errores; se intenta igualmente instalar Firefox por si el repositorio de Mozilla sí se descargó bien."
    fi

    # --- 3) Instalación de Firefox normal (PRIMERO, antes de tocar ESR) ---
    # No se usa "apt-cache policy" como comprobación previa: puede dar
    # falso negativo (sin candidato visible) aunque "apt install" funcione
    # perfectamente. La única forma fiable de saber si Firefox está
    # disponible es intentar instalarlo de verdad.
    if sudo apt install -y firefox; then
      MOZILLA_READY=1

      # Los paquetes de idioma de Mozilla no usan el código de 2 letras a
      # secas: van por variante regional (es-es, es-ar, es-mx...), igual
      # que ya hacía firefox-esr-l10n-*. "firefox-l10n-es" no siempre
      # existe de verdad; se comprueba en tiempo de ejecución cuál sí,
      # empezando por la variante de España.
      FIREFOX_L10N_CANDIDATES=(firefox-l10n-es-es firefox-l10n-es-mx firefox-l10n-es-ar firefox-l10n-es)
      FIREFOX_L10N_PKG=""
      for pkg in "${FIREFOX_L10N_CANDIDATES[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
          FIREFOX_L10N_PKG="$pkg"
          break
        fi
      done

      if confirm "¿Instalar también el paquete de idioma español${FIREFOX_L10N_PKG:+ ($FIREFOX_L10N_PKG)}?"; then
        if [[ -n "$FIREFOX_L10N_PKG" ]]; then
          sudo apt install -y "$FIREFOX_L10N_PKG" \
            || warn "No se pudo instalar $FIREFOX_L10N_PKG. Reintenta luego con: sudo apt install $FIREFOX_L10N_PKG"
        else
          warn "No se encontró ningún paquete de idioma español disponible (se probó: ${FIREFOX_L10N_CANDIDATES[*]}). Busca el nombre exacto con: apt-cache search firefox-l10n"
        fi
      fi

      ok "Firefox de Mozilla instalado. Comprueba la versión con: firefox --version"
    else
      FIREFOX_INSTALL_FAILED=1
      warn "No se pudo instalar Firefox de Mozilla. Se omite la sustitución; ESR y sus perfiles no se han tocado."
      warn "Reintenta manualmente con: sudo apt update && sudo apt install firefox"
    fi
  fi

  # --- 4) Eliminación de Firefox ESR y sus datos (SOLO si Firefox normal
  # ya quedó instalado y funcionando) ---
  if [[ "$MOZILLA_READY" -eq 1 ]]; then
    ESR_PURGED=0
    if [[ ${#FIREFOX_ESR_PKGS[@]} -gt 0 ]]; then
      log "Quitando Firefox ESR: ${FIREFOX_ESR_PKGS[*]}"
      # "purge" en vez de "remove": si se usa "remove", dpkg deja el
      # paquete en estado "rc" (removido, config sin purgar) y
      # /etc/firefox-esr queda con restos de config para siempre.
      if sudo apt purge -y "${FIREFOX_ESR_PKGS[@]}"; then
        ESR_PURGED=1
        sudo apt autoremove -y || warn "'apt autoremove' falló (no es crítico)."
      else
        ESR_PURGE_FAILED=1
        warn "No se pudo eliminar Firefox ESR: puede seguir instalado junto a Firefox normal. Por seguridad no se toca /etc/firefox-esr ni se borran sus perfiles."
      fi
    else
      warn "Firefox ESR no estaba instalado como paquete (o ya se había quitado antes). No se borra ningún perfil."
    fi

    # Solo se borra /etc/firefox-esr si el purge terminó bien o si ESR ya
    # no estaba instalado (resto huérfano). Si el purge falla, ESR puede
    # seguir instalado y su configuración se deja intacta.
    if [[ -d /etc/firefox-esr && ( "$ESR_PURGED" -eq 1 || ${#FIREFOX_ESR_PKGS[@]} -eq 0 ) ]]; then
      # dpkg no borra el directorio si queda algo dentro que no le
      # pertenece a ningún paquete (por ejemplo /etc/firefox-esr/pref/).
      log "Quitando restos de configuración en /etc/firefox-esr"
      sudo rm -rf /etc/firefox-esr
    fi

    if [[ "$ESR_PURGED" -eq 1 && -d "$MOZILLA_PROFILES_DIR" ]]; then
      log "Eliminando perfiles y datos de Firefox ESR: $MOZILLA_PROFILES_DIR"
      if rm -rf -- "$MOZILLA_PROFILES_DIR"; then
        ESR_PROFILES_REMOVED=1
        ok "Perfiles y datos de Firefox ESR eliminados."
      else
        warn "No se pudieron eliminar por completo los perfiles de $MOZILLA_PROFILES_DIR. Revísalo a mano."
      fi
    fi
  fi
else
  warn "Se omite la sustitución de Firefox."
fi

# ----------------------------------------------------------------------
# 8. Driver NVIDIA (opcional)
# ----------------------------------------------------------------------
#
# Solo se ofrece si se detecta una GPU NVIDIA por lspci. El patrón es
# detectar -> preguntar -> instalar por repo oficial (cuda-keyring), sin
# pinear versión: "nvidia-open" (sin "=X.Y.Z-N") deja que apt resuelva
# siempre la más reciente disponible en el repo CUDA en el momento en
# que se ejecute el script, en vez de quedarse anclado a una versión
# concreta que acabará desapareciendo del repo.
#
# LIMITACIÓN CONOCIDA: "nvidia-open" (el módulo de kernel open-source)
# solo soporta GPUs Turing en adelante (RTX 20xx, GTX 16xx, y más
# recientes). En GPUs anteriores (Pascal, Maxwell...) no carga. El
# script no distingue el modelo concreto, solo detecta "es NVIDIA" — el
# aviso se muestra en pantalla antes de pedir confirmación, pero queda
# en manos del usuario saber si su GPU es compatible.
#
# Secure Boot / MOK enrollment queda deliberadamente FUERA de este
# script: es un procedimiento manual e interactivo (requiere reiniciar y
# confirmar en la pantalla de MOK Manager), así que aquí solo se detecta
# y se avisa, remitiendo a MANUAL.md. Automatizarlo sería más frágil que
# útil para un equipo personal.

NVIDIA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb"

GPU_INFO=""
if ensure_cmd lspci pciutils; then
  GPU_INFO="$(lspci | grep -Ei 'vga|3d' || true)"
else
  warn "No se puede detectar la GPU sin 'lspci'; se omiten las secciones de NVIDIA y switcheroo-control."
fi

# Estado de Secure Boot: imprime "enabled", "disabled", "noefi" (sistema
# sin UEFI o sin soporte de Secure Boot: no aplica) o "unknown".
# Primero se usa mokutil, si está instalado; si no, se lee directamente la
# variable EFI SecureBoot (el último byte vale 1 si está activado).
# No se instala ningún paquete para esta comprobación.
detect_secure_boot() {
  local state efivar value
  if command -v mokutil >/dev/null 2>&1; then
    state="$(mokutil --sb-state 2>/dev/null || true)"
    case "${state,,}" in
      *"secureboot enabled"*)  echo "enabled";  return 0 ;;
      *"secureboot disabled"*) echo "disabled"; return 0 ;;
      *"not supported"*|*"doesn't support"*) echo "noefi"; return 0 ;;
    esac
  fi

  if [[ ! -d /sys/firmware/efi ]]; then
    echo "noefi"
    return 0
  fi

  efivar="$(compgen -G '/sys/firmware/efi/efivars/SecureBoot-*' | head -n 1 || true)"
  if [[ -n "$efivar" && -r "$efivar" ]]; then
    value="$(od -An -t u1 -j 4 -N 1 "$efivar" 2>/dev/null | tr -d '[:space:]' || true)"
    case "$value" in
      1) echo "enabled";  return 0 ;;
      0) echo "disabled"; return 0 ;;
    esac
  fi

  echo "unknown"
}

if echo "$GPU_INFO" | grep -qi nvidia; then
  NVIDIA_LINE="$(echo "$GPU_INFO" | grep -i nvidia)"

  # Secure Boot se comprueba ANTES de instalar, para que se sepa de
  # antemano si hará falta completar el proceso MOK/firma del módulo.
  SECURE_BOOT_STATE="$(detect_secure_boot)"
  case "$SECURE_BOOT_STATE" in
    enabled)
      SB_NOTE="ATENCIÓN: Secure Boot está ACTIVADO. Tras instalar, el módulo del kernel de NVIDIA no cargará hasta que completes el proceso de firma/MOK (requiere reiniciar y confirmar en el MOK Manager; consulta MANUAL.md)."
      warn "$SB_NOTE"
      ;;
    disabled)
      SB_NOTE="Secure Boot está desactivado: no hace falta firmar el módulo de NVIDIA."
      log "$SB_NOTE"
      ;;
    noefi)
      SB_NOTE="Este sistema no arranca en modo UEFI o no soporta Secure Boot: no aplica el proceso de firma MOK."
      log "$SB_NOTE"
      ;;
    *)
      SB_NOTE="AVISO: no se ha podido determinar el estado de Secure Boot. Si lo tienes activado, tras instalar puede hacer falta completar el proceso de firma/MOK (consulta MANUAL.md)."
      warn "$SB_NOTE"
      ;;
  esac

  if [[ "$WGET_OK" -ne 1 ]] && ! dpkg -s cuda-keyring >/dev/null 2>&1; then
    warn "Se ha detectado una GPU NVIDIA, pero falta 'wget' (necesario para añadir el repositorio de NVIDIA) y no se pudo instalar. Se omite el driver NVIDIA."
  elif confirm "GPU NVIDIA detectada:\n  ${NVIDIA_LINE}\n\nAviso: este paso instala 'nvidia-open', el módulo de kernel de código abierto de NVIDIA, vía el repositorio CUDA oficial de NVIDIA. Solo soporta GPUs Turing en adelante (RTX 20xx, GTX 16xx, RTX 30xx/40xx/50xx...). En una GPU más antigua (GTX 10xx y anteriores) este driver no cargará; en ese caso necesitarías el paquete 'nvidia-driver' (propietario clásico) en su lugar. El script no comprueba el modelo concreto, solo que el fabricante sea NVIDIA.\n\n${SB_NOTE}\n\n¿Instalar el driver NVIDIA (nvidia-open, última versión disponible en el repo)?" 28 76; then

    # --- Repositorio de NVIDIA (cuda-keyring) ---
    NVIDIA_REPO_READY=0
    if dpkg -s cuda-keyring >/dev/null 2>&1; then
      ok "El repositorio de NVIDIA (cuda-keyring) ya está instalado."
      NVIDIA_REPO_READY=1
    else
      log "Añadiendo el repositorio de NVIDIA (cuda-keyring)..."
      NVIDIA_KEYRING_TMP="$(mktemp --suffix=.deb)"
      if wget -qO "$NVIDIA_KEYRING_TMP" "$NVIDIA_KEYRING_URL" && [[ -s "$NVIDIA_KEYRING_TMP" ]]; then
        if sudo dpkg -i "$NVIDIA_KEYRING_TMP"; then
          NVIDIA_REPO_READY=1
        else
          warn "No se pudo instalar cuda-keyring (falló 'dpkg -i')."
        fi
      else
        warn "No se pudo descargar cuda-keyring desde $NVIDIA_KEYRING_URL (¿sin conexión o URL cambiada?)."
      fi
      rm -f "$NVIDIA_KEYRING_TMP"
    fi

    if [[ "$NVIDIA_REPO_READY" -ne 1 ]]; then
      warn "Se omite la instalación del driver NVIDIA: el repositorio de NVIDIA no está disponible. No se ha tocado nouveau ni GRUB."
    else

      # Pin de origen para el repo NVIDIA CUDA (mismo patrón que Mozilla en
      # la sección 7). Sin esto, paquetes como nvidia-driver-libs también
      # existen de forma nativa en el repo non-free de Debian con una
      # versión distinta; sin pin explícito, APT podría resolver algún
      # paquete del stack NVIDIA desde un origen distinto al resto,
      # mezclando versiones entre el módulo de kernel y las librerías.
      #
      # Los comodines 'nvidia-*' / 'libnvidia-*' NO cubren (a) paquetes del
      # driver con otros nombres (libcuda1, libglx-nvidia0, libegl-nvidia0,
      # libgles-nvidia*, libnvcuvid1, libnvoptix1, libxnvctrl0,
      # xserver-xorg-video-nvidia, firmware-nvidia-gsp), ni (b) las variantes
      # de 32 bits (':i386'): en las pruebas, los comodines no les aplicaron el
      # pin, así que se nombran explícitamente. Si una versión nueva del
      # driver renombra alguno de estos paquetes (p. ej. libnvidia-egl-wayland21),
      # añade aquí el nombre nuevo.
      log "Fijando el repositorio de NVIDIA como origen preferente para el stack nvidia-*..."
      sudo tee /etc/apt/preferences.d/nvidia-cuda >/dev/null <<'EOF'
Package: nvidia-* libnvidia-* libegl-nvidia* libgles-nvidia* libglx-nvidia* libcuda1 libcudadebugger1 libnvcuvid1 libnvoptix1 libxnvctrl0 xserver-xorg-video-nvidia firmware-nvidia-gsp
Pin: origin developer.download.nvidia.com
Pin-Priority: 1000

Package: nvidia-driver-libs:i386 nvidia-vulkan-icd:i386 libcuda1:i386 libegl-nvidia0:i386 libgles-nvidia1:i386 libgles-nvidia2:i386 libglx-nvidia0:i386
Pin: origin developer.download.nvidia.com
Pin-Priority: 1000

Package: libnvidia-allocator1:i386 libnvidia-egl-gbm1:i386 libnvidia-egl-wayland21:i386 libnvidia-egl-xcb1:i386 libnvidia-egl-xlib1:i386 libnvidia-eglcore:i386 libnvidia-glcore:i386 libnvidia-glvkspirv:i386 libnvidia-gpucomp:i386 libnvidia-ml1:i386 libnvidia-ptxjitcompiler1:i386
Pin: origin developer.download.nvidia.com
Pin-Priority: 1000
EOF

      log "Instalando el driver NVIDIA (sin pinear versión -> se resuelve la más reciente del repo, ahora con origen fijado)..."
      sudo dpkg --add-architecture i386
      if ! sudo apt update; then
        warn "'apt update' terminó con errores; se intenta la instalación con los índices disponibles."
      fi

      # Si esta instalación falla NO se toca nouveau ni GRUB: bloquear
      # nouveau sin tener el driver de NVIDIA funcionando dejaría el
      # sistema sin driver gráfico para esa GPU.
      if ! sudo apt install -y \
        linux-headers-amd64 \
        firmware-misc-nonfree \
        dkms \
        nvidia-open \
        nvidia-kernel-open-dkms \
        nvidia-settings \
        libvulkan-dev \
        nvidia-vulkan-icd \
        vulkan-tools \
        vulkan-validationlayers \
        nvidia-driver-libs:i386 \
        nvidia-vaapi-driver; then
        warn "Falló la instalación del driver NVIDIA. No se ha tocado nouveau ni GRUB, para no dejar el sistema sin driver gráfico."
        warn "Revisa el error de arriba y reintenta: sudo apt install nvidia-open nvidia-kernel-open-dkms nvidia-driver-libs:i386"
      else

        log "Deshabilitando el driver nouveau..."
        sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

        # Fichero propio (no se tocan los de los paquetes NVIDIA).
        # NVreg_PreserveVideoMemoryAllocations=1 hace coherentes los
        # servicios nvidia-suspend/hibernate/resume que se habilitan más
        # abajo. NVreg_TemporaryFilePath=/var/tmp se usa para que el volcado
        # de la VRAM no vaya a /tmp, que en Debian puede ser un tmpfs (RAM).
        # Ojo: /var/tmp tampoco garantiza por sí solo estar en disco (depende
        # de cómo esté montado), y el sistema de archivos que lo contenga
        # debe tener espacio libre suficiente para volcar la VRAM completa.
        log "Configurando la preservación de memoria de vídeo para suspensión/hibernación..."
        sudo tee /etc/modprobe.d/nvidia-preserve-vram.conf >/dev/null <<'EOF'
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
EOF

        log "Configurando GRUB para KMS de NVIDIA..."
        NVIDIA_GRUB_PARAMS=(nvidia-drm.modeset=1 nvidia-drm.fbdev=1)
        if [[ ! -f /etc/default/grub ]]; then
          warn "No se encontró /etc/default/grub (¿otro gestor de arranque?); se omite la configuración de GRUB."
          warn "Añade a mano estos parámetros del kernel en tu gestor de arranque: ${NVIDIA_GRUB_PARAMS[*]}"
        else
          NVIDIA_GRUB_BACKUP="/etc/default/grub.bak.$(date +%Y%m%d%H%M%S)"
          sudo cp /etc/default/grub "$NVIDIA_GRUB_BACKUP"
          ok "Copia de seguridad: $NVIDIA_GRUB_BACKUP"

          # En vez de sobrescribir GRUB_CMDLINE_LINUX_DEFAULT entero (lo que
          # borraría cualquier otro parámetro de arranque que ya tuvieras,
          # p. ej. resume=, iommu=, mitigations=, etc.), se añaden solo los
          # parámetros de NVIDIA a lo que ya hubiera. Se comprueba clave por
          # clave para no duplicarlos si el script se re-ejecuta.
          CURRENT_CMDLINE="$(grep -oP '^GRUB_CMDLINE_LINUX_DEFAULT="\K[^"]*' /etc/default/grub || true)"

          NEW_CMDLINE="$CURRENT_CMDLINE"
          for param in "${NVIDIA_GRUB_PARAMS[@]}"; do
            key="${param%%=*}"
            if [[ "$NEW_CMDLINE" != *"$key"* ]]; then
              NEW_CMDLINE="${NEW_CMDLINE:+$NEW_CMDLINE }${param}"
            fi
          done

          if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
            sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_CMDLINE}\"|" /etc/default/grub
          else
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${NEW_CMDLINE}\"" | sudo tee -a /etc/default/grub >/dev/null
          fi
          ok "GRUB_CMDLINE_LINUX_DEFAULT resultante: ${NEW_CMDLINE}"

          # command -v no alcanza aquí: update-grub vive en /usr/sbin, que
          # no está en el $PATH de un usuario normal en Debian (solo en el
          # de root/sudo). Por eso se comprueba también la ruta directa.
          if command -v update-grub >/dev/null 2>&1 || [[ -x /usr/sbin/update-grub ]]; then
            sudo update-grub || warn "update-grub ha fallado; revisa la configuración de GRUB y ejecútalo a mano: sudo update-grub"
          else
            warn "No se encontró 'update-grub'; regenera la configuración de GRUB manualmente."
          fi
        fi

        # "-k all": el blacklist de nouveau y las opciones de modprobe
        # quedan en los initramfs de TODOS los kernels instalados, no solo
        # del que está en ejecución. Un error puntual (p. ej. un kernel
        # sin /lib/modules) no debe abortar todo el script.
        sudo update-initramfs -u -k all \
          || warn "update-initramfs devolvió un error en algún kernel; revisa la salida de arriba. Puedes reintentarlo con: sudo update-initramfs -u -k all"

        log "Habilitando servicios de suspensión/hibernación de NVIDIA..."
        for svc in nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service; do
          if sudo systemctl enable "$svc" 2>/dev/null; then
            ok "Servicio habilitado: $svc"
          else
            warn "Servicio $svc no disponible en este empaquetado del driver, se omite."
          fi
        done

        NVIDIA_INSTALLED=1

        if [[ "$SECURE_BOOT_STATE" == "enabled" ]]; then
          warn "Secure Boot está ACTIVADO en este sistema."
          warn "El módulo del kernel de NVIDIA no cargará hasta que firmes la clave MOK."
          warn "Este paso es manual (requiere reiniciar y confirmar en el MOK Manager)."
          warn "Consulta la sección 'Secure Boot / NVIDIA' en MANUAL.md ANTES de reiniciar."
        elif [[ "$SECURE_BOOT_STATE" == "unknown" ]]; then
          warn "No se pudo determinar el estado de Secure Boot. Si lo tienes activado, consulta la sección 'Secure Boot / NVIDIA' en MANUAL.md ANTES de reiniciar."
        fi
      fi
    fi
  else
    warn "Se omite la instalación del driver NVIDIA."
  fi
fi

# ----------------------------------------------------------------------
# 9. switcheroo-control (gestión de GPU híbrida, opcional)
# ----------------------------------------------------------------------
#
# switcheroo-control es el servicio D-Bus oficial de Debian (el mismo
# enfoque por defecto de Fedora y CachyOS) para exponer la disponibilidad
# de GPU dual (integrada + dedicada) y permitir el cambio entre ellas. No
# es específico de ningún fabricante de portátil: solo tiene sentido si
# hay de verdad dos GPUs, así que se detecta reutilizando $GPU_INFO (ya
# calculado en la sección NVIDIA) contando cuántos controladores VGA/3D
# reporta lspci -- 2 o más significa gráficos híbridos, sea la
# combinación que sea (Intel+NVIDIA, AMD+NVIDIA, etc.).

GPU_COUNT="$(echo "$GPU_INFO" | grep -c . || true)"

if [[ "$GPU_COUNT" -ge 2 ]]; then
  GPU_LIST="$(echo "$GPU_INFO" | sed 's/^/  /')"
  if confirm "Se han detectado $GPU_COUNT controladores de vídeo (GPU híbrida: integrada + dedicada):\n\n${GPU_LIST}\n\n¿Instalar switcheroo-control para gestionar el cambio de GPU?" 18 76; then
    SWITCHEROO_OK=1
    if dpkg -s switcheroo-control >/dev/null 2>&1; then
      ok "switcheroo-control ya está instalado."
    elif ! sudo apt install -y switcheroo-control; then
      warn "No se pudo instalar switcheroo-control. Reintenta luego con: sudo apt install switcheroo-control"
      SWITCHEROO_OK=0
    fi

    if [[ "$SWITCHEROO_OK" -eq 1 ]]; then
      if sudo systemctl enable --now switcheroo-control; then
        ok "switcheroo-control instalado y activo. Comprueba las GPUs detectadas con: switcherooctl list"
        SWITCHEROO_INSTALLED=1
      else
        warn "No se pudo habilitar/arrancar switcheroo-control. Reintenta luego con: sudo systemctl enable --now switcheroo-control"
      fi
    fi
  else
    warn "Se omite la instalación de switcheroo-control."
  fi
fi

# ----------------------------------------------------------------------
# 10. Resumen final
# ----------------------------------------------------------------------

cat <<EOF

Instalación completada.

CPU detectada: ${CPU_MODEL_NAME}

Notas:
  - fd-find se instala como binario "fdfind", no "fd" (conflicto de
    nombre en Debian). Si lo quieres como "fd":
      mkdir -p ~/.local/bin
      ln -s "\$(command -v fdfind)" ~/.local/bin/fd

  - Puede que haga falta reiniciar sesión (o el sistema) para que
    algunos cambios de firmware/microcode surtan efecto.

  - Synaptic ya está instalado: desde el menú de aplicaciones (o
    "synaptic-pkexec" por terminal). Para instalar un .deb suelto
    (descargado manualmente), hazlo desde Discover o con:
      sudo apt install ./archivo.deb

  - GNOME Disk Utility ya está instalado (comando: gnome-disks) para
    gestionar discos y particiones desde una interfaz gráfica.

  - Si instalaste las fuentes de Windows y/o de Ubuntu, ya están
    disponibles para cualquier aplicación (LibreOffice, navegadores,
    etc.).

  - Si configuraste zram, comprueba su estado cuando quieras con:
      zramswap status
      swapon --show
    Para desactivarlo más adelante:
      sudo systemctl disable --now zramswap
      sudo apt remove zram-tools
    La configuración previa (si existía) quedó respaldada junto a
    /etc/default/zramswap con un sufijo .bak.<fecha>.
    Si además ajustaste vm.swappiness, comprueba el valor activo con:
      sudo sysctl vm.swappiness

  - Si instalaste Firefox desde el repositorio de Mozilla, comprueba
    la versión con: firefox --version (debería ser una versión release,
    no "esr" en el nombre). Para revertir a Firefox ESR de Debian:
      sudo apt remove firefox
      sudo rm /etc/apt/sources.list.d/mozilla.sources \
              /etc/apt/sources.list.d/mozilla.list \
              /etc/apt/preferences.d/mozilla 2>/dev/null
      sudo apt update
      sudo apt install firefox-esr

  - Si usaste -y, revisa que no se haya omitido ningún aviso importante
    de debconf (se silencian en modo no interactivo).

  - Si el script detectó y comentó contenido en /etc/apt/sources.list
    (típico de una instalación desde la ISO oficial), tienes la copia
    original en /etc/apt/sources.list.bak.<fecha> por si quieres
    revisarla o revertir el cambio.
EOF

if [[ "${ESR_PROFILES_REMOVED:-0}" -eq 1 ]]; then
  cat <<'EOF'

  - Se eliminaron también los perfiles y datos de Firefox ESR
    (~/.mozilla/firefox).
    Al abrir el Firefox nuevo se creará un perfil limpio desde cero
    (sin marcadores/contraseñas del ESR anterior).
EOF
fi

if [[ "${NVIDIA_INSTALLED:-0}" -eq 1 ]]; then
  cat <<'EOF'

  - Driver NVIDIA instalado (nvidia-open, última versión del repo),
    junto con librerías de 32 bits (nvidia-driver-libs:i386, para
    Steam/Proton) y nvidia-vaapi-driver (aceleración de vídeo por
    hardware en navegadores). El repo NVIDIA CUDA se fijó como origen
    preferente para todo el stack nvidia-*/libnvidia-* (ver
    /etc/apt/preferences.d/nvidia-cuda).
    Reinicia para que cargue el nuevo driver. Si tienes Secure Boot
    activado, no reinicies sin antes seguir la sección 'Secure Boot /
    NVIDIA' de MANUAL.md (enrollment de la clave MOK).
    Verifica tras reiniciar con: nvidia-smi
EOF
fi

if [[ "${SWITCHEROO_INSTALLED:-0}" -eq 1 ]]; then
  cat <<'EOF'

  - switcheroo-control instalado y activo (gestión de GPU híbrida).
    Comprueba las GPUs detectadas con: switcherooctl list
    Para desactivarlo más adelante:
      sudo systemctl disable --now switcheroo-control
      sudo apt remove switcheroo-control
EOF
fi

if [[ "${FULL_UPGRADE_FAILED:-0}" -eq 1 ]]; then
  echo
  echo "  - ATENCIÓN: 'apt full-upgrade' falló durante la ejecución y el script"
  echo "    continuó con el resto de pasos. Cuando puedas, resuélvelo y reintenta:"
  echo "      sudo apt update && sudo apt full-upgrade"
fi

if [[ "${ESR_PURGE_FAILED:-0}" -eq 1 ]]; then
  echo
  echo "  - ATENCIÓN: no se pudo eliminar Firefox ESR, así que puede seguir"
  echo "    instalado junto a Firefox de Mozilla. Su configuración (/etc/firefox-esr)"
  echo "    y sus perfiles no se han tocado. Cuando puedas, reintenta:"
  echo "      sudo apt purge firefox-esr firefox-esr-l10n-es"
fi

if [[ "${FIREFOX_INSTALL_FAILED:-0}" -eq 1 ]]; then
  echo
  echo "  - ATENCIÓN: no se pudo instalar Firefox de Mozilla (Firefox ESR ya se"
  echo "    había eliminado si estaba instalado). Reintenta con:"
  echo "      sudo apt update && sudo apt install firefox"
fi

if [[ ${#FAILED_GROUPS[@]} -gt 0 ]]; then
  echo
  echo "  - ATENCIÓN: los siguientes grupos de paquetes fallaron durante la"
  echo "    instalación y se omitieron (revisa el log de arriba y reintenta"
  echo "    a mano con 'sudo apt install <paquetes>'):"
  printf '      · %s\n' "${FAILED_GROUPS[@]}"
fi

echo "Detalles completos de cada paso en MANUAL.md."

if [[ "$ASSUME_YES" -ne 1 ]]; then
  if [[ "${NVIDIA_INSTALLED:-0}" -eq 1 ]]; then
    if whiptail --title "$TITLE" \
        --yes-button "Reiniciar ahora" --no-button "Reiniciar después" \
        --yesno "Instalación completada.\n\nSe instaló el driver NVIDIA: hace falta reiniciar para que cargue.\n\n¿Reiniciar ahora?" 14 70; then
      sudo reboot
    else
      ok "Recuerda reiniciar manualmente para que el driver NVIDIA entre en uso."
    fi
  else
    whiptail --title "$TITLE" --msgbox "Instalación completada.\n\nRevisa el resumen impreso en la terminal para los detalles y próximos pasos." 12 70
  fi
fi
