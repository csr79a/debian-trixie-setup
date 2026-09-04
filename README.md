# setup-debian-trixie.sh

Script de configuración inicial para **Debian 13 (trixie)** con KDE Plasma.
Automatiza la configuración de repositorios, la actualización del sistema,
la instalación de un set de paquetes de desarrollo/multimedia/sistema
(incluyendo Synaptic y GDebi como gestores de paquetes gráficos), el
microcode correcto según el fabricante de CPU, un dispositivo zram de 8 GB
de swap comprimido en RAM (opcional), la sustitución de Firefox ESR por el
Firefox oficial de Mozilla (opcional), y añade el remoto de Flathub.

---

## Índice

- [Qué hace](#qué-hace)
- [sources.list clásico preexistente](#sourceslist-clásico-preexistente)
- [Requisitos previos: dejar sudo listo](#requisitos-previos-dejar-sudo-listo)
- [Requisitos](#requisitos)
- [Uso](#uso)
- [Qué se instala](#qué-se-instala)
- [ZRAM: swap comprimido en RAM (8 GB)](#zram-swap-comprimido-en-ram-8-gb)
- [Firefox oficial de Mozilla](#firefox-oficial-de-mozilla)
- [Detalles importantes](#detalles-importantes)
- [Después de ejecutarlo](#después-de-ejecutarlo)
- [Solución de problemas](#solución-de-problemas)
- [Idempotencia](#idempotencia)
- [Licencia](#licencia)

---

## Qué hace

El script ejecuta, en orden, los siguientes pasos:

1. Comprueba que no se ejecuta como `root` y que el sistema usa `apt`.
2. Avisa si el codename detectado no es `trixie` (permite continuar bajo confirmación).
3. Si `/etc/apt/sources.list` tiene contenido activo (típico de una
   instalación desde la ISO oficial, a veces con entrada de CD-ROM), hace
   una copia de seguridad y lo comenta, para que no compita con el nuevo
   `debian.sources` (ver [sección dedicada](#sourceslist-clásico-preexistente)).
4. Escribe `/etc/apt/sources.list.d/debian.sources` en formato **deb822**
   (repos `main`, `contrib`, `non-free`, `non-free-firmware` para trixie,
   trixie-security y trixie-backports). **No sobrescribe** el archivo si ya existe.
5. Ejecuta `apt update` y, opcionalmente, `apt full-upgrade`.
6. Detecta el fabricante de la CPU (`Intel`/`AMD`) para instalar el paquete
   de microcode correspondiente.
7. Instala un conjunto de paquetes, incluyendo Synaptic y GDebi (ver
   [tabla completa](#qué-se-instala)).
8. Añade el remoto de **Flathub** si no está ya configurado.
9. Pregunta si quieres configurar un dispositivo **zram** de 8 GB de swap
   comprimido en RAM (ver [sección dedicada](#zram-swap-comprimido-en-ram-8-gb)).
10. Pregunta si quieres sustituir Firefox ESR por el **Firefox oficial de
    Mozilla** (ver [sección dedicada](#firefox-oficial-de-mozilla)).
11. Muestra notas finales (p. ej. sobre `fd-find`, Synaptic/GDebi, zram, Firefox
    y el sources.list clásico neutralizado).

---

## sources.list clásico preexistente

Si instalaste Debian desde la ISO oficial (sobre todo el DVD), es muy
probable que `/etc/apt/sources.list` ya tenga contenido activo, a veces
incluyendo una entrada `cdrom://`. Si el script escribiera su propio
`debian.sources` (deb822) sin tocar ese archivo, `apt` acabaría con las
mismas suites y componentes definidos dos veces (avisos de "está
configurado varias veces") y fallaría al intentar actualizar la entrada
de CD-ROM.

Para evitarlo, antes de crear `debian.sources` el script:

1. Comprueba si `/etc/apt/sources.list` tiene líneas `deb`/`deb-src`
   activas (no comentarios ni vacías).
2. Si las tiene, pide confirmación (respeta `-y`) y, si aceptas, hace una
   copia de seguridad (`sources.list.bak.<fecha>`) y comenta esas líneas.
3. A partir de ahí, `debian.sources` es la única fuente de los repos
   oficiales de Debian.

Si prefieres revisarlo tú mismo antes de nada, revierte con:

```bash
sudo cp /etc/apt/sources.list.bak.<fecha> /etc/apt/sources.list
```

---

## Requisitos previos: dejar sudo listo

**Importante:** Debian **no** configura `sudo` automáticamente en todos los
casos — y esto no depende de si elegiste una instalación mínima o completa
(con escritorio, etc.). Depende de un paso concreto del instalador:

- Si **dejaste en blanco** la contraseña de `root` durante la instalación,
  Debian instala `sudo` y da privilegios de administrador a tu usuario
  automáticamente.
- Si **pusiste una contraseña a `root`** (como es habitual), Debian asume
  que vas a administrar el sistema entrando como root directamente, y
  **no instala `sudo` ni añade tu usuario a ningún grupo** — da igual que
  hayas instalado el sistema completo con KDE Plasma u otro escritorio.

Es decir: es muy probable que necesites este paso aunque tu instalación
sea "completa", si en su momento configuraste una contraseña de root.
El script lo comprueba y se detiene con instrucciones si falta algo, pero
es mejor dejarlo resuelto antes de ejecutarlo.

Si tras instalar Debian solo tienes la contraseña de `root`, haz esto
**una única vez**, antes de usar el script:

```bash
# 1. Entra como root
su -

# 2. Instala sudo
apt update
apt install sudo

# 3. Añade tu usuario normal al grupo sudo (sustituye TU_USUARIO)
usermod -aG sudo TU_USUARIO

# 4. Sal de la sesión de root
exit
```

Después, **cierra sesión de tu usuario y vuelve a entrar** (o reinicia),
para que el cambio de grupo se aplique. Puedes comprobar que todo está
en orden con:

```bash
groups
# debería incluir "sudo" en la lista

sudo -v
# debería pedirte tu contraseña de usuario (no la de root) y no dar error
```

Si `sudo -v` funciona sin errores, ya puedes ejecutar `setup-debian-trixie.sh`
con normalidad.

> Nota: si durante la instalación **dejaste en blanco** la contraseña de
> root, es muy probable que `sudo` ya esté listo y puedas saltarte este
> apartado — el script lo detectará automáticamente en cualquier caso.

---

## Requisitos

- Debian 13 (trixie) — probado en esta versión. Otras versiones basadas en
  APT pueden funcionar parcialmente, pero no está garantizado.
- `sudo` instalado y usuario en el grupo `sudo` (ver apartado anterior).
- Conexión a internet (repos oficiales de Debian y Flathub).
- Entorno KDE Plasma si quieres aprovechar `plasma-discover-backend-flatpak`
  (el resto de paquetes no dependen de KDE).

---

## Uso

```bash
chmod +x setup-debian-trixie.sh

# Modo interactivo (por defecto): pide confirmación en cada paso relevante
./setup-debian-trixie.sh

# Modo no interactivo: asume "sí" en todas las confirmaciones
./setup-debian-trixie.sh -y
# o
./setup-debian-trixie.sh --yes

# Ayuda
./setup-debian-trixie.sh -h
```

En modo `-y`, además se exporta `DEBIAN_FRONTEND=noninteractive` para evitar
que `apt`/`debconf` se queden esperando input (por ejemplo, avisos de
licencia de firmware no libre). Esto también silencia **cualquier otro**
prompt de debconf durante la instalación — revisa la salida después si
usas este modo.

> **Importante:** no ejecutes este script con `curl ... | bash` sin `-y`.
> Las confirmaciones (`read -rp`) necesitan una entrada estándar interactiva
> de terminal; si la entrada estándar viene de una tubería, la primera
> pregunta hará fallar el script. Descarga el archivo primero y ejecútalo
> localmente, o usa `-y` si de verdad quieres modo no interactivo.

Al principio, el script también comprueba que `sudo` esté instalado y
valida tus credenciales con `sudo -v` antes de tocar nada. Si algo falla
ahí, verás un mensaje claro señalando este README en vez de un error de
`sudo` a mitad de instalación.

---

## Qué se instala

| Categoría | Paquetes |
|---|---|
| Control de versiones / descargas | `git`, `git-lfs`, `curl`, `wget` |
| Compresión | `unzip`, `zip`, `7zip` |
| Sistema / diagnóstico | `btop`, `fastfetch`, `tree`, `jq`, `ripgrep`, `fd-find`, `pciutils`, `usbutils`, `lshw`, `dmidecode`, `inxi`, `hwinfo`, `lm-sensors`, `acpi` |
| Desarrollo / compilación | `build-essential`, `gcc`, `g++`, `make`, `cmake`, `ninja-build`, `pkg-config`, `autoconf`, `automake`, `libtool`, `openssh-client` |
| Multimedia | `ffmpeg`, `gstreamer1.0-libav`, `gstreamer1.0-plugins-good/bad/ugly`, `pavucontrol` |
| Firmware | `firmware-linux` (metapaquete, ver nota abajo) |
| Gestión de paquetes (GUI) | `synaptic`, `gdebi` |
| Flatpak / KDE | `flatpak`, `plasma-discover-backend-flatpak` |
| Microcode | `intel-microcode` o `amd64-microcode`, según CPU detectada |
| ZRAM (opcional, con confirmación aparte) | `zram-tools`, configurado a 8 GiB fijos |

---

## ZRAM: swap comprimido en RAM (8 GB)

### Qué es y para qué sirve

zram crea un dispositivo de intercambio (swap) que vive **comprimido en
RAM** en vez de en disco. Es mucho más rápido que el swap tradicional en
HDD/SSD y ayuda a que el sistema no se quede corto de memoria en picos de
uso, sin el desgaste de escritura de un swapfile en disco.

### Qué hace el script exactamente

Es un paso **independiente** de la instalación de paquetes, con su propia
confirmación (respeta `-y` igual que el resto):

1. Instala `zram-tools` si no está ya instalado.
2. Hace una copia de seguridad de `/etc/default/zramswap` antes de tocarlo
   (con sufijo `.bak.<fecha>`).
3. Detecta si tu versión de `zram-tools` usa la variable `SIZE` o
   `ALLOCATION` para fijar un tamaño absoluto (varía según versión), y
   fija esa variable a **8192** (8 GiB en MiB, la unidad que usa
   zram-tools).
4. Comenta cualquier variable de porcentaje (`PERCENT`/`PERCENTAGE`) que
   estuviera activa, porque si queda activa tiene prioridad sobre el
   tamaño fijo y lo ignoraría silenciosamente.
5. Reinicia el servicio `zramswap` y muestra el estado resultante
   (`zramctl` / `swapon --show`).

Si el script no reconoce el formato del archivo de configuración (por
ejemplo, una versión de `zram-tools` con variables distintas a las
esperadas), **no modifica nada automáticamente** — para no dejar una
configuración inconsistente — y te avisa para que lo revises a mano
siguiendo [wiki.debian.org/ZRam](https://wiki.debian.org/ZRam).

### Comprobar y revertir

```bash
# Ver el estado actual
zramswap status
swapon --show

# Desactivarlo si ya no lo quieres
sudo systemctl disable --now zramswap
sudo apt remove zram-tools

# Recuperar la configuración previa (si la había) desde el backup
sudo cp /etc/default/zramswap.bak.<fecha> /etc/default/zramswap
sudo systemctl restart zramswap
```

---

## Firefox oficial de Mozilla

### Por qué existe este paso

Debian, por motivos de licencia de marca, no distribuye "Firefox" a
secas: instala **`firefox-esr`** (versión de soporte extendido, con
ciclo de actualización más lento y unos meses por detrás de la versión
"release" que usan la mayoría de usuarios de otras distros). Este paso,
**opcional y con confirmación propia**, lo sustituye por el Firefox
oficial de Mozilla, instalado desde el repositorio APT que la propia
Mozilla publica y mantiene.

El procedimiento sigue la [guía oficial de
Mozilla](https://support.mozilla.org/kb/install-firefox-linux) para
paquetes `.deb`, con estas adaptaciones respecto al texto original:

- **Se omite todo lo específico de Ubuntu/snap** (fijar `firefox` desde
  snap, pines de prioridad negativa para el paquete snap, etc.) — no
  aplica en Debian.
- **Formato de repositorio detectado automáticamente**: usa el formato
  moderno **deb822** (`mozilla.sources`) en trixie y posteriores, o el
  formato clásico de una línea (`mozilla.list`) si el script se está
  ejecutando en un codename anterior (p. ej. bookworm) tras aceptar el
  aviso de compatibilidad de la sección 1.
- **Verificación de huella digital no omitible**: si la huella de la
  clave descargada no coincide exactamente con la publicada por Mozilla
  (`35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3`), el script **aborta este
  paso sin añadir el repositorio ni instalar nada**, y borra la clave
  descargada. Es la misma comprobación de seguridad que recomienda
  Mozilla, simplemente automatizada.

### Qué hace el script exactamente

1. Si `firefox-esr` (y/o `firefox-esr-l10n-es`) está instalado, lo quita.
2. Crea `/etc/apt/keyrings` si no existe y descarga la clave de firma de
   Mozilla ahí.
3. Verifica la huella digital de esa clave contra el valor oficial.
4. Si coincide, añade el repositorio de Mozilla (`mozilla.sources` o
   `mozilla.list`, según el caso) y un fichero de prioridad
   (`/etc/apt/preferences.d/mozilla`) para que sus paquetes tengan
   preferencia frente a cualquier otro repo que también publique algo
   llamado `firefox`.
5. Ejecuta `apt update` e instala `firefox`.
6. Pregunta, aparte, si quieres instalar también el paquete de idioma
   español (`firefox-l10n-es`).

### Comprobar y revertir

```bash
# Comprobar que es la versión de Mozilla (no debería decir "esr")
firefox --version

# Volver a Firefox ESR de Debian
sudo apt remove firefox
sudo rm /etc/apt/sources.list.d/mozilla.sources \
        /etc/apt/sources.list.d/mozilla.list \
        /etc/apt/preferences.d/mozilla 2>/dev/null
sudo apt update
sudo apt install firefox-esr
```

---

## Detalles importantes

### Repositorios no libres

El `sources.list` generado activa los componentes `contrib`, `non-free` y
`non-free-firmware`. Si te importa distribuir software estrictamente libre,
edita la sección 2 del script antes de ejecutarlo.

### `firmware-linux`

Es un metapaquete que instala **todo** el firmware no libre disponible
(`firmware-linux-nonfree`), no solo el de tu hardware concreto. Es cómodo
pero añade volumen innecesario. Alternativa más quirúrgica:

```bash
lspci -k          # identifica el hardware y el driver en uso
sudo apt install firmware-misc-nonfree firmware-iwlwifi   # ejemplo
```

### `fd-find`

Debian lo empaqueta como binario `fdfind` (no `fd`, por conflicto de
nombre con otro paquete). Para tener el comando `fd`:

```bash
mkdir -p ~/.local/bin
ln -s "$(command -v fdfind)" ~/.local/bin/fd
```

Asegúrate de que `~/.local/bin` esté en tu `$PATH`.

### Synaptic y GDebi

- **Synaptic**: gestor de paquetes gráfico completo — buscar, instalar,
  quitar, fijar versiones, ver dependencias. Se abre desde el menú de
  aplicaciones o con `synaptic-pkexec` en terminal (te pide la
  autenticación con `polkit`, no hace falta anteponer `sudo`).
- **GDebi**: instala archivos `.deb` sueltos (por ejemplo, descargados de
  la web) resolviendo automáticamente sus dependencias, algo que abrir el
  archivo con doble clic no siempre hace bien. Uso:
  ```bash
  sudo gdebi ruta/al/archivo.deb
  ```
  o desde su interfaz gráfica, abriendo el `.deb` con GDebi.

### `apt full-upgrade`

Se ofrece como paso opcional tras cambiar/crear el `sources.list`. Es
recomendable aceptarlo la primera vez que ejecutas el script en un sistema
recién instalado o con repos distintos, para partir de un estado consistente.

---

## Después de ejecutarlo

- Puede que necesites **reiniciar sesión o el sistema** para que el
  microcode/firmware surta efecto completamente.
- Verifica Flathub:
  ```bash
  flatpak remote-list
  ```
- Verifica el microcode instalado:
  ```bash
  dmesg | grep -i microcode
  ```

---

## Solución de problemas

| Problema | Causa probable | Solución |
|---|---|---|
| `Error: "sudo" no está instalado` | Instalación mínima de Debian | Ver [Requisitos previos](#requisitos-previos-dejar-sudo-listo) |
| `el usuario no pertenece al grupo "sudo"` | No se añadió el usuario al grupo, o no se ha reiniciado sesión tras añadirlo | `usermod -aG sudo TU_USUARIO` como root, luego cerrar sesión y volver a entrar |
| `apt update` falla | Sin conexión o mirror caído | Reintenta o cambia de mirror en el `sources.list` |
| El script se detiene pidiendo input inesperado | Prompt de debconf (p. ej. licencia de firmware) | Usa `-y` para modo no interactivo, o responde manualmente |
| `fd: command not found` tras instalar | Es normal, ver [sección `fd-find`](#fd-find) | Crea el symlink indicado |
| Aviso de codename distinto de `trixie` | Estás en otra versión/derivada de Debian | Revisa compatibilidad antes de continuar |
| Avisos "está configurado varias veces" en `apt update`, o error de `cdrom://` | `/etc/apt/sources.list` clásico seguía activo junto al nuevo `debian.sources` | Ejecuta el script de nuevo (o edita `/etc/apt/sources.list` a mano y comenta sus líneas `deb`) |

---

## Idempotencia

El script se puede volver a ejecutar sin problema:

- No sobrescribe `debian.sources` si ya existe.
- Si `/etc/apt/sources.list` ya fue comentado en una ejecución anterior,
  no queda contenido activo que volver a comentar.
- `apt install` sobre paquetes ya instalados no hace nada.
- Flathub no se vuelve a añadir si ya está configurado.

---

## Licencia

MIT
