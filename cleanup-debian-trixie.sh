#!/usr/bin/env bash
#
# cleanup-debian-trixie.sh
#
# Elimina aplicaciones de KDE Plasma que Debian instala por defecto junto
# a la tarea "KDE Plasma Workspaces" pero que muchos usuarios no llegan a
# usar (suite PIM/Kontact, algunas herramientas de accesibilidad,
# Konqueror). Pensado como complemento independiente de
# setup-debian-trixie.sh: ese script instala, este quita.
#
# El script está organizado en GRUPOS. Cada grupo se revisa y confirma
# por separado, y solo intenta eliminar los paquetes de ese grupo que
# estén realmente instalados. Por defecto usa "apt remove" (deja los
# ficheros de configuración); usa --purge si además quieres borrarlos.
#
# Uso:
#   chmod +x cleanup-debian-trixie.sh
#   ./cleanup-debian-trixie.sh              # modo interactivo, un grupo cada vez
#   ./cleanup-debian-trixie.sh -y            # no interactivo, confirma todos los grupos "seguros"
#   ./cleanup-debian-trixie.sh --purge       # como el anterior pero borrando también configuración
#   ./cleanup-debian-trixie.sh --imagemagick # además, evalúa quitar ImageMagick (ver aviso abajo)
#
# Licencia: MIT

set -euo pipefail

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
      echo "  -y, --yes      No pedir confirmación por grupo (modo no interactivo)."
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

confirm() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  local ans
  read -rp "$prompt [y/N] " ans
  [[ "${ans,,}" == "y" ]]
}

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
  exit 1
fi

echo "Comprobando permisos de sudo..."
if ! sudo -v; then
  echo "No se pudieron validar los permisos de sudo." >&2
  exit 1
fi

# ----------------------------------------------------------------------
# 2. Utilidades
# ----------------------------------------------------------------------

is_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

# remove_group <nombre> <pkg1> [pkg2 ...]
# Filtra a los paquetes realmente instalados, los enumera, pide
# confirmación de grupo y, si se acepta, deja que "apt remove/purge"
# muestre su propio resumen de la transacción (dependencias que se
# arrastran, huérfanos, etc.) antes de tocar nada.
remove_group() {
  local group_name="$1"
  shift
  local candidates=("$@")
  local to_remove=()

  for pkg in "${candidates[@]}"; do
    if is_installed "$pkg"; then
      to_remove+=("$pkg")
    fi
  done

  echo
  echo "== Grupo: $group_name =="
  if [[ ${#to_remove[@]} -eq 0 ]]; then
    echo "Nada que hacer (ninguno de estos paquetes está instalado)."
    return
  fi

  echo "Instalados en este grupo: ${to_remove[*]}"
  if ! confirm "¿Eliminar este grupo con 'apt $APT_ACTION'?"; then
    echo "Grupo omitido."
    return
  fi

  # Sin -y aquí: dejamos que apt muestre su propio resumen (incluyendo
  # cualquier dependencia que se lleve por delante) y pida confirmación,
  # salvo que el usuario haya pedido explícitamente modo no interactivo.
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    sudo apt "$APT_ACTION" -y "${to_remove[@]}"
  else
    sudo apt "$APT_ACTION" "${to_remove[@]}"
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
)

# GRUPO 2 — Accesibilidad
# Independientes del grupo PIM: no se eliminan solos al quitar KMail.
ACCESSIBILITY_GROUP=(
  kmousetool
  kmouth
  kontrast
)

# GRUPO 3 — Konqueror
# Navegador/gestor de archivos antiguo de KDE, sin relación con los
# grupos anteriores.
KONQUEROR_GROUP=(
  konqueror
)

# GRUPO 4 (opcional, --imagemagick) — ImageMagick
# ¡OJO! No es una app de Plasma: es una utilidad/librería que usan otros
# programas por debajo (miniaturas, importación/exportación de imágenes
# en otras apps). Antes de quitarlo de verdad, revisa qué depende de él:
#   apt-cache rdepends imagemagick
# Por eso este grupo NO se evalúa a menos que pases --imagemagick, y
# siempre se muestra rdepends antes de pedir confirmación.
IMAGEMAGICK_GROUP=(
  imagemagick
)

# ----------------------------------------------------------------------
# 4. Ejecución
# ----------------------------------------------------------------------

echo "Este script revisará, grupo por grupo, aplicaciones de KDE Plasma"
echo "instaladas por defecto en Debian que muchos usuarios no llegan a usar."
echo "No se eliminará nada sin confirmación explícita de cada grupo."

remove_group "Suite PIM / Kontact (KMail, KAddressBook, KTnef, editores de tema, Sieve, exportador PIM)" "${PIM_GROUP[@]}"
remove_group "Accesibilidad (KMouseTool, KMouth, Kontrast)" "${ACCESSIBILITY_GROUP[@]}"
remove_group "Konqueror" "${KONQUEROR_GROUP[@]}"

if [[ "$INCLUDE_IMAGEMAGICK" -eq 1 ]]; then
  echo
  echo "== Grupo opcional: ImageMagick =="
  if is_installed imagemagick; then
    echo "ImageMagick no es una app de Plasma: puede que otros programas lo usen"
    echo "por debajo. Paquetes que dependen de él (apt-cache rdepends):"
    apt-cache rdepends imagemagick | sed -n '1,15p'
    echo
    if confirm "¿Aun así quieres eliminarlo?"; then
      if [[ "$ASSUME_YES" -eq 1 ]]; then
        sudo apt "$APT_ACTION" -y imagemagick
      else
        sudo apt "$APT_ACTION" imagemagick
      fi
    else
      echo "Se omite ImageMagick."
    fi
  else
    echo "ImageMagick no está instalado."
  fi
fi

echo
if confirm "¿Ejecutar 'apt autoremove' para limpiar dependencias huérfanas?"; then
  sudo apt autoremove
fi

cat <<'EOF'

Limpieza completada.

Notas:
  - Se usó "apt remove" (o "apt purge" si pasaste --purge). Con "remove"
    los ficheros de configuración en tu $HOME y en /etc no se tocan; si
    quieres borrarlos también, vuelve a ejecutar con --purge.
  - Si más adelante echas en falta alguna app, se reinstala igual que
    cualquier otro paquete: sudo apt install <paquete>.
  - Este script es intencionadamente conservador: pide confirmación por
    grupo y dentro de cada "apt remove/purge" verás el resumen real de
    la transacción antes de que se aplique (salvo en modo -y).
EOF
