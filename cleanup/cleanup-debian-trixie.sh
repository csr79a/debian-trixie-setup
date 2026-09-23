#!/usr/bin/env bash
#
# cleanup-debian-trixie.sh — Limpiador de Debian Trixie csr79a
#
# Elimina aplicaciones de KDE Plasma que Debian instala por defecto junto
# a la tarea "KDE Plasma Workspaces" pero que muchos usuarios no llegan a
# usar (suite PIM/Kontact, algunas herramientas de accesibilidad,
# Konqueror). Pensado como complemento independiente de
# setup-debian-trixie.sh: ese script instala, este quita.
#
# El script está organizado en GRUPOS. Cada grupo se revisa y confirma
# por separado (pantalla whiptail), y solo intenta eliminar los paquetes
# de ese grupo que estén realmente instalados. Por defecto usa "apt
# remove" (deja los ficheros de configuración); usa --purge si además
# quieres borrarlos.
#
# Uso:
#   chmod +x cleanup-debian-trixie.sh
#   ./cleanup-debian-trixie.sh              # modo interactivo, un grupo cada vez
#   ./cleanup-debian-trixie.sh -y            # no interactivo, confirma todos los grupos "seguros"
#   ./cleanup-debian-trixie.sh --purge       # como el anterior pero borrando también configuración
#   ./cleanup-debian-trixie.sh --imagemagick # además, evalúa quitar ImageMagick (ver aviso abajo)
#
# Historial de versiones:
#   1.1.0 - Hardening portado desde cleanup-debian-sid.sh:
#           * is_installed() ahora distingue el estado real "install ok
#             installed" de un estado "rc" (eliminado con "apt remove"
#             pero con config residual, típico si ya se corrió este
#             script antes sin --purge); antes, "dpkg -s" devolvía
#             éxito también en estado "rc" y se volvía a ofrecer
#             eliminar algo que ya no estaba instalado.
#           * remove_group(), el bloque de ImageMagick y el
#             autoremove/autoclean final ahora envuelven cada
#             "apt remove/purge/autoremove/autoclean" en un if/else.
#             Con "set -e" activo, si el usuario respondía "no" a la
#             propia pregunta [Y/n] de apt (o si apt fallaba por
#             cualquier otro motivo), el comando devolvía un código
#             distinto de 0 y eso mataba TODO el script ahí mismo, sin
#             procesar el resto de los grupos ni el resumen final. Un
#             "no" o un fallo de apt ahora se trata como "se omite este
#             paso", igual que un "no" de whiptail.
#           * Añadidos los grupos "Dragon Player" y "Juk" (reproductores
#             multimedia de KDE que muchos usuarios sustituyen por otros).
#           * Añadido el grupo "KDE Partition Manager", con su propia
#             función (no usa el remove_group() genérico): avisa si
#             gnome-disk-utility no está instalado, porque en ese caso
#             eliminar KDE Partition Manager dejaría el sistema sin
#             gestor de particiones gráfico.
#   1.0.0 - Versión base.
#
# Nota: desde la versión 1.3.0 de setup-debian-trixie.sh, ese script
# instala gnome-disk-utility (grupo "Utilidades de disco"), igual que
# setup-debian-sid.sh. El aviso de gnome-disk-utility en el grupo "KDE
# Partition Manager" de aquí abajo solo se dispara si, pese a eso, no lo
# tienes instalado (lo quitaste a mano, instalación antigua con una
# versión anterior del setup, etc.).
#
# Licencia: MIT

set -euo pipefail

TITLE="Limpiador de Debian Trixie csr79a"
VERSION="1.1.0"

log()   { echo -e "\e[1;34m[*]\e[0m $*"; }
ok()    { echo -e "\e[1;32m[OK]\e[0m $*"; }
warn()  { echo -e "\e[1;33m[!]\e[0m $*"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

# ----------------------------------------------------------------------
# 0. Opciones de línea de comandos
# ----------------------------------------------------------------------

ASSUME_YES=0
PURGE=0
INCLUDE_IMAGEMAGICK=0
APT_ACTION="remove"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    --purge)
      PURGE=1
      APT_ACTION="purge"
      shift
      ;;
    --imagemagick)
      INCLUDE_IMAGEMAGICK=1
      shift
      ;;
    -h|--help)
      echo "Uso: $0 [-y|--yes] [--purge] [--imagemagick]"
      echo "  -y, --yes      No pedir confirmación por grupo (modo no interactivo, sin pantallas)."
      echo "  --purge        Usar 'apt purge' en vez de 'apt remove' (borra también config)."
      echo "  --imagemagick  Evaluar también la eliminación de ImageMagick (grupo aparte, ver README)."
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      exit 1
      ;;
  esac
done

# Pequeño helper para confirmaciones. En modo -y no se muestra ninguna
# pantalla; en modo interactivo, cada decisión se muestra como una
# pantalla whiptail --yesno (devuelve 0=Sí / 1=No, usable directamente
# en un "if confirm...").
confirm() {
  local prompt="$1"
  local height="${2:-16}"
  local width="${3:-74}"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  whiptail --title "$TITLE" --yesno "$prompt" "$height" "$width"
}

# Con -y también evitamos que apt/debconf se queden esperando input
# (p. ej. algún paquete con prompt de debconf al desinstalarse). OJO:
# esto silencia TODOS los prompts de debconf durante la limpieza, no
# solo los relacionados con los paquetes de este script, así que solo
# se activa en modo no interactivo explícito.
if [[ "$ASSUME_YES" -eq 1 ]]; then
  export DEBIAN_FRONTEND=noninteractive
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

if ! command -v whiptail >/dev/null 2>&1; then
  log "Instalando whiptail (necesario para las pantallas de este script)..."
  sudo apt update
  sudo apt install -y whiptail
fi

log "Comprobando permisos de sudo..."
if ! sudo -v; then
  error "No se pudieron validar los permisos de sudo. Revisa la sección 'Requisitos previos: dejar sudo listo' del README."
fi

# ----------------------------------------------------------------------
# Pantalla de bienvenida
# ----------------------------------------------------------------------

WELCOME_MSG="Versión del Limpiador de Debian Trixie csr79a ${VERSION}

Este programa revisa, grupo por grupo, aplicaciones de KDE Plasma instaladas por defecto en Debian que muchos usuarios no llegan a usar (suite PIM/Kontact, accesibilidad, Konqueror, xterm, KDE Connect, Dragon Player, Juk, KDE Partition Manager, e ImageMagick de forma opcional).

No se eliminará nada sin confirmación explícita de cada grupo."

if [[ "$PURGE" -eq 1 ]]; then
  WELCOME_MSG+="

Modo --purge activo: se usará 'apt purge' (borra también archivos de configuración)."
fi

confirm "$WELCOME_MSG

¿Desea continuar?" 22 74 || exit 0

DETECTED_CODENAME=""
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  DETECTED_CODENAME="${VERSION_CODENAME:-}"
  if [[ "$DETECTED_CODENAME" != "trixie" ]]; then
    confirm "Aviso: este script está probado en Debian trixie (13).\n\nSe ha detectado: ${PRETTY_NAME:-desconocido}.\n\nLos nombres de paquete de este script se verificaron para trixie; en otras versiones podrían no existir o haber cambiado.\n\n¿Quieres continuar de todas formas?" || exit 1
  fi
fi

# ----------------------------------------------------------------------
# 2. Utilidades
# ----------------------------------------------------------------------

is_installed() {
  # dpkg -s también devuelve éxito para paquetes en estado "rc"
  # (eliminados con "apt remove" pero con config residual, algo típico
  # si ya corriste este script antes sin --purge). Comprobamos el
  # estado real ("install ok installed") para no volver a ofrecer
  # eliminar algo que ya no está instalado.
  local status
  status="$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" || return 1
  [[ "$status" == "install ok installed" ]]
}

# remove_group <nombre> <descripcion_paquetes> <pkg1> [pkg2 ...]
# Filtra a los paquetes realmente instalados, pide confirmación de grupo
# en una pantalla whiptail (incluyendo qué paquetes se verían afectados)
# y, si se acepta, deja que "apt remove/purge" muestre su propio resumen
# de la transacción (dependencias que se arrastran, huérfanos, etc.) en
# la terminal antes de tocar nada.
remove_group() {
  local group_name="$1"
  local group_desc="$2"
  shift 2
  local candidates=("$@")
  local to_remove=()

  for pkg in "${candidates[@]}"; do
    if is_installed "$pkg"; then
      to_remove+=("$pkg")
    fi
  done

  log "Grupo: $group_name"
  if [[ ${#to_remove[@]} -eq 0 ]]; then
    ok "Nada que hacer (ninguno de estos paquetes está instalado)."
    return
  fi

  if ! confirm "Grupo: ${group_name}\n\n${group_desc}\n\nInstalados en este grupo: ${to_remove[*]}\n\n¿Eliminar este grupo con 'apt ${APT_ACTION}'?" 18 76; then
    warn "Grupo omitido."
    return
  fi

  # Sin -y aquí: dejamos que apt muestre su propio resumen (incluyendo
  # cualquier dependencia que se lleve por delante) en la terminal
  # normal, salvo que el usuario haya pedido explícitamente modo no
  # interactivo.
  #
  # IMPORTANTE: esto va dentro de un if/else a propósito. Con "set -e"
  # activo, si el usuario contesta "n" en la pregunta [Y/n] de apt (o
  # si apt falla por cualquier otro motivo), el comando devuelve un
  # código distinto de 0 -- y sin este if, eso mataría TODO el script
  # ahí mismo, dejando sin procesar el resto de los grupos, el
  # autoremove/autoclean final y el resumen. Tratamos un "no" de apt
  # como "se omite este grupo", igual que un "no" de whiptail.
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    if sudo apt "$APT_ACTION" -y "${to_remove[@]}"; then
      ok "Grupo '${group_name}' procesado."
    else
      warn "Grupo '${group_name}': falló 'apt ${APT_ACTION}'. Se omite y se continúa con el resto."
    fi
  else
    if sudo apt "$APT_ACTION" "${to_remove[@]}"; then
      ok "Grupo '${group_name}' procesado."
    else
      warn "Grupo '${group_name}': cancelado o falló 'apt ${APT_ACTION}'. Se continúa con el resto."
    fi
  fi
}

# ----------------------------------------------------------------------
# 3. Grupos de paquetes
# ----------------------------------------------------------------------
#
# GRUPO 1 — Suite PIM / Kontact
# KMail, KAddressBook, KTnef (paquete de transición, se fusiona en kmail),
# el editor de temas de Contact y de encabezados de KMail (ambos vienen
# en el mismo paquete kdepim-themeeditors), el editor de filtros Sieve
# (pim-sieve-editor) y el exportador de preferencias de PIM
# (pim-data-exporter). Todos comparten árbol de dependencias con Akonadi,
# así que suelen caer juntos al quitar kmail.
PIM_GROUP=(
  kmail
  kaddressbook
  ktnef
  kdepim-themeeditors
  pim-sieve-editor
  pim-data-exporter
  korganizer
  akregator
)
PIM_DESC="KMail, KAddressBook, KTnef, editores de tema, Sieve, exportador PIM, KOrganizer, Akregator. Comparten árbol de dependencias con Akonadi."

# GRUPO 2 — Accesibilidad
# Independientes del grupo PIM: no se eliminan solos al quitar KMail.
ACCESSIBILITY_GROUP=(
  kmousetool
  kmouth
  kontrast
)
ACCESSIBILITY_DESC="KMouseTool, KMouth, Kontrast. Independientes del grupo PIM."

# GRUPO 3 — Konqueror
# Navegador/gestor de archivos antiguo de KDE, sin relación con los
# grupos anteriores.
KONQUEROR_GROUP=(
  konqueror
)
KONQUEROR_DESC="Navegador/gestor de archivos antiguo de KDE."

# GRUPO 3b — xterm
# Emulador de terminal genérico de X11, nada que ver con KDE ni con los
# grupos anteriores. Suele venir como dependencia de meta-paquetes de
# X11/escritorio, no de Plasma en sí, así que va en su propio grupo.
XTERM_GROUP=(
  xterm
)
XTERM_DESC="Emulador de terminal genérico de X11, sin relación con KDE Plasma."

# GRUPO 3c — KDE Connect
# Integra el móvil con el escritorio (notificaciones, compartir
# archivos, control remoto...). Independiente de todo lo anterior: no
# comparte árbol de dependencias con PIM, accesibilidad, Konqueror ni
# xterm, así que va en su propio grupo.
KDECONNECT_GROUP=(
  kdeconnect
  kdeconnect-libs
  qml6-module-org-kde-kdeconnect
)
KDECONNECT_DESC="KDE Connect (app), sus librerías internas (kdeconnect-libs) y el módulo QML (qml6-module-org-kde-kdeconnect). Independiente del resto de grupos."

# GRUPO 3d — Dragon Player
# Reproductor de vídeo por defecto de Plasma. Sin relación de
# dependencias con el resto de grupos.
DRAGONPLAYER_GROUP=(
  dragonplayer
)
DRAGONPLAYER_DESC="Reproductor de vídeo por defecto de Plasma."

# GRUPO 3e — Juk
# Reproductor/gestor de música de KDE. Independiente de Dragon Player
# (paquetes distintos, sin dependencias cruzadas).
JUK_GROUP=(
  juk
)
JUK_DESC="Reproductor/gestor de música de KDE."

# GRUPO 3f — KDE Partition Manager
# A diferencia de los demás grupos, este no usa remove_group() genérico:
# comprueba explícitamente si gnome-disk-utility está instalado para
# avisar si no habría alternativa gráfica de gestión de discos/
# particiones tras la eliminación. setup-debian-trixie.sh NO instala
# gnome-disk-utility por defecto, así que este aviso es puramente
# informativo aquí (a diferencia de la versión de setup-debian-sid.sh,
# no asume que ya tengas una alternativa instalada por el script de
# setup complementario).
remove_partitionmanager_group() {
  log "Grupo: KDE Partition Manager"
  if ! is_installed partitionmanager; then
    ok "Nada que hacer (partitionmanager no está instalado)."
    return
  fi

  local warning_text=""
  if ! is_installed gnome-disk-utility; then
    warning_text="\n\nAVISO: gnome-disk-utility NO está instalado en este sistema. Si eliminas KDE Partition Manager, te quedarás sin gestor de particiones gráfico salvo que instales uno (p. ej.: sudo apt install gnome-disk-utility)."
  fi

  if ! confirm "Instalado: partitionmanager${warning_text}\n\n¿Eliminar este grupo con 'apt ${APT_ACTION}'?" 18 78; then
    warn "Grupo omitido."
    return
  fi

  # Ver el comentario equivalente en remove_group(): sin el if/else acá,
  # un "no" en la pregunta de apt (o un fallo) cortaría todo el script
  # por "set -e" y no llegaría a procesar ImageMagick, autoremove, etc.
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    if sudo apt "$APT_ACTION" -y partitionmanager; then
      ok "Grupo 'KDE Partition Manager' procesado."
    else
      warn "Grupo 'KDE Partition Manager': falló 'apt ${APT_ACTION}'. Se omite y se continúa."
    fi
  else
    if sudo apt "$APT_ACTION" partitionmanager; then
      ok "Grupo 'KDE Partition Manager' procesado."
    else
      warn "Grupo 'KDE Partition Manager': cancelado o falló 'apt ${APT_ACTION}'. Se continúa."
    fi
  fi
}

# GRUPO 4 (opcional, --imagemagick) — ImageMagick
# ¡OJO! No es una app de Plasma: es una utilidad/librería que usan otros
# programas por debajo (miniaturas, importación/exportación de imágenes
# en otras apps). Antes de quitarlo de verdad, revisa qué depende de él:
#   apt-cache rdepends imagemagick
# Por eso este grupo NO se evalúa a menos que pases --imagemagick, y
# siempre se muestra rdepends antes de pedir confirmación.

# ----------------------------------------------------------------------
# 4. Ejecución
# ----------------------------------------------------------------------

remove_group "Suite PIM / Kontact" "$PIM_DESC" "${PIM_GROUP[@]}"
remove_group "Accesibilidad" "$ACCESSIBILITY_DESC" "${ACCESSIBILITY_GROUP[@]}"
remove_group "Konqueror" "$KONQUEROR_DESC" "${KONQUEROR_GROUP[@]}"
remove_group "xterm" "$XTERM_DESC" "${XTERM_GROUP[@]}"
remove_group "KDE Connect" "$KDECONNECT_DESC" "${KDECONNECT_GROUP[@]}"
remove_group "Dragon Player" "$DRAGONPLAYER_DESC" "${DRAGONPLAYER_GROUP[@]}"
remove_group "Juk" "$JUK_DESC" "${JUK_GROUP[@]}"
remove_partitionmanager_group

if [[ "$INCLUDE_IMAGEMAGICK" -eq 1 ]]; then
  log "Grupo opcional: ImageMagick"
  if is_installed imagemagick; then
    RDEPENDS="$(apt-cache rdepends imagemagick | sed -n '1,15p')"
    warn "ImageMagick no es una app de Plasma: puede que otros programas lo usen por debajo."
    echo "$RDEPENDS"
    if confirm "ImageMagick no es una app de Plasma: puede que otros programas lo usen por debajo (miniaturas, importación/exportación de imágenes).\n\nPaquetes que dependen de él (primeras líneas, lista completa arriba en la terminal):\n\n$(echo "$RDEPENDS" | head -n 8)\n\n¿Aun así quieres eliminarlo?" 20 76; then
      # Mismo motivo que en remove_group(): if/else para que un "no" o
      # un fallo de apt no corte el script antes del autoremove/autoclean.
      if [[ "$ASSUME_YES" -eq 1 ]]; then
        if sudo apt "$APT_ACTION" -y imagemagick; then
          ok "ImageMagick eliminado."
        else
          warn "Falló 'apt ${APT_ACTION} imagemagick'. Se omite y se continúa."
        fi
      else
        if sudo apt "$APT_ACTION" imagemagick; then
          ok "ImageMagick eliminado."
        else
          warn "Cancelado o falló 'apt ${APT_ACTION} imagemagick'. Se continúa."
        fi
      fi
    else
      warn "Se omite ImageMagick."
    fi
  else
    ok "ImageMagick no está instalado."
  fi
fi

if confirm "¿Ejecutar 'apt autoremove' para limpiar dependencias huérfanas?"; then
  if sudo apt autoremove; then
    ok "autoremove completado."
  else
    warn "Cancelado o falló 'apt autoremove'. Se continúa igualmente."
  fi
fi

if confirm "¿Ejecutar 'apt autoclean' para limpiar el caché de paquetes .deb descargados que ya no están disponibles?"; then
  if sudo apt autoclean; then
    ok "autoclean completado."
  else
    warn "Cancelado o falló 'apt autoclean'. Se continúa igualmente."
  fi
fi

cat <<'EOF'

Limpieza completada.

Notas:
  - Se usó "apt remove" (o "apt purge" si pasaste --purge). Con "remove"
    los ficheros de configuración en tu $HOME y en /etc no se tocan; si
    quieres borrarlos también, vuelve a ejecutar con --purge.
  - Si más adelante echas en falta alguna app, se reinstala igual que
    cualquier otro paquete: sudo apt install <paquete>.
  - Si quitaste KDE Partition Manager y necesitas gestionar discos o
    particiones, instala una alternativa gráfica (p. ej.:
    sudo apt install gnome-disk-utility) o usa la terminal (parted,
    fdisk, gparted).
  - Este script es intencionadamente conservador: pide confirmación por
    grupo y dentro de cada "apt remove/purge" verás el resumen real de
    la transacción antes de que se aplique (salvo en modo -y).
  - En Debian trixie (stable) es poco probable que estos paquetes
    reaparezcan solos, ya que la rama estable no reintroduce
    dependencias nuevas fuera de las actualizaciones de seguridad y los
    "point releases". Si tras una actualización de este tipo vuelve a
    aparecer alguno, ejecuta de nuevo este script.
EOF

if [[ "$ASSUME_YES" -ne 1 ]]; then
  whiptail --title "$TITLE" --msgbox "Limpieza completada.\n\nRevisa el resumen impreso en la terminal para los detalles." 12 70
fi
