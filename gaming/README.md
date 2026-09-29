# Gaming en Debian Trixie 13

Scripts para preparar y limpiar un entorno de gaming en **Debian Trixie 13**, con especial atención a Steam/Proton, GameMode, MangoHud, Protontricks, Heroic y herramientas auxiliares.

El proyecto está pensado para instalar lo necesario sin forzar una instalación de Wine del sistema cuando la combinación disponible en Debian Trixie 13 no es adecuada.

## Qué incluye

- Steam.
- Proton y herramientas relacionadas.
- ProtonPlus para gestionar builds de Proton-GE.
- Protontricks mediante `pipx`.
- Winetricks como script oficial.
- GameMode.
- MangoHud compilado desde fuente con soporte NVML cuando corresponde.
- MangoJuice como interfaz gráfica opcional.
- Heroic Games Launcher.
- Lutris y Gamescope como componentes opcionales.
- `game-performance` para ejecutar juegos con el perfil de energía de rendimiento cuando está disponible.
- Configuración de `ntsync`.
- Ajustes del sistema relacionados con juegos modernos.
- Herramientas de diagnóstico como `mesa-utils`.

## Scripts

### Instalación

`gaming/setup-gaming-debian-trixie.sh`

Instala y configura el entorno de gaming para Debian Trixie 13. El script está diseñado para poder ejecutarse de nuevo sin intentar duplicar configuraciones ya existentes.

### Limpieza

`gaming/cleanup-gaming-debian-trixie.sh`

Revierte los componentes instalados o configurados por el script de instalación.

Incluye una limpieza específica de lanzadores `.desktop` de Steam que puedan quedar en el menú de aplicaciones después de desinstalar Steam.

> La limpieza no borra por defecto tus juegos ni tus datos personales.

## Requisitos

- Debian GNU/Linux 13 (Trixie).
- Una sesión de usuario normal; los scripts solicitan `sudo` cuando necesitan privilegios.
- Conexión a Internet para descargar paquetes y código fuente.
- Repositorios APT de Trixie correctamente configurados.
- El instalador configura `trixie-backports` si no existe, sin tocar una configuración de Backports que ya tengas.
- Protontricks se instala mediante `pipx` y su GUI mediante `protontricks-desktop-install`.
- Flatpak es opcional y se utiliza para ProtonPlus y, si lo eliges, MangoJuice.

## Instalación

Descarga o clona el repositorio y ejecuta:

```bash
chmod +x gaming/setup-gaming-debian-trixie.sh
./gaming/setup-gaming-debian-trixie.sh
```

El script muestra cada bloque y continúa según las opciones disponibles en el sistema.

## Comprobación posterior

Después de la instalación se pueden comprobar algunos componentes con:

```bash
steam
gamemoderun true
gamescope --version
mangohud --version
protontricks --version
winetricks --version
game-performance --help
```

Para Protontricks, que no aparezcan juegos inmediatamente no significa necesariamente que exista un problema: debe existir al menos un juego de Steam ejecutado mediante Proton para que Protontricks pueda detectarlo.

## Gamescope y Trixie Backports

Gamescope no se toma del repositorio estable principal de Trixie en este proyecto. Si eliges instalarlo, se obtiene explícitamente de `trixie-backports` mediante `apt install -t trixie-backports gamescope`.

El instalador solo elimina durante la limpieza el fichero de Backports que él mismo haya creado y que lleve su marca. Si ya tenías Backports configurado, no lo elimina.

## MangoHud

MangoHud se compila desde fuente con soporte NVML (`-Dwith_nvml=enabled`). El proyecto no sustituye esta compilación por el paquete `mangohud` de Debian.

## Wine y Winetricks

El proyecto no fuerza la instalación de Wine del sistema.

En Debian Trixie 13 puede ocurrir que no exista una combinación de paquetes Wine nativos adecuada para el sistema actual. Steam utiliza su propia infraestructura Proton para los juegos compatibles.

Por ese motivo:

- Protontricks se utiliza para juegos de Steam/Proton.
- Winetricks se mantiene como herramienta disponible para prefijos Wine tradicionales.
- Si no hay `wine`/`wineserver` del sistema, Winetricks puede mostrar un aviso y no podrá gestionar prefijos Wine normales.
- Esto no impide utilizar Steam + Proton.

## Steam y el icono que queda después de desinstalar

La limpieza contempla dos situaciones diferentes:

1. El paquete de Steam sigue instalado.
2. El paquete ya fue eliminado, pero quedó un lanzador `.desktop` de usuario.

El limpiador comprueba estos lanzadores conocidos:

```text
~/.local/share/applications/steam.desktop
~/.local/share/applications/steam-native.desktop
~/.local/share/applications/steam-url-handler.desktop
~/.local/share/applications/steam-launcher.desktop
```

Si existen, el script muestra cuáles encontró y ofrece eliminarlos.

No elimina automáticamente:

```text
~/.steam
~/.local/share/Steam
~/Games
```

ni otros datos de juegos.

## Limpieza

Primero se recomienda una simulación:

```bash
chmod +x gaming/cleanup-gaming-debian-trixie.sh
./gaming/cleanup-gaming-debian-trixie.sh --dry-run
```

Para ejecutar la limpieza interactiva:

```bash
./gaming/cleanup-gaming-debian-trixie.sh
```

Para aceptar las confirmaciones normales:

```bash
./gaming/cleanup-gaming-debian-trixie.sh -y
```

Para ofrecer además el borrado de datos personales de juegos:

```bash
./gaming/cleanup-gaming-debian-trixie.sh --purge-data
```

`--purge-data` es deliberadamente más restrictivo y requiere una confirmación explícita escribiendo `BORRAR`.

## Qué NO hace la limpieza por defecto

El limpiador no elimina:

- Tus juegos.
- Tus partidas locales.
- `~/.steam`.
- `~/.local/share/Steam`.
- `~/Games`.
- La arquitectura `i386`.
- `power-profiles-daemon`.
- Flatpak ni el remoto Flathub.
- Paquetes de desarrollo que puedan ser utilizados por otros programas.

## ntsync en Debian Trixie

El kernel estable de Trixie puede no proporcionar `ntsync`. En ese caso el instalador lo informa y continúa: no se considera un fallo fatal. Si utilizas un kernel de Trixie Backports con soporte para `ntsync`, puedes volver a ejecutar el instalador para configurarlo.

## Estructura del proyecto

```text
.
├── README.md
├── gaming/setup-gaming-debian-trixie.sh
├── gaming/cleanup-gaming-debian-trixie.sh
└── docs
    ├── README.md
    ├── MANUAL.md
    ├── INSTALACION.md
    └── DESINSTALACION.md
```

## Documentación

- [Manual completo](gaming/docs/MANUAL.md)
- [Desinstalación y limpieza](gaming/docs/DESINSTALACION.md)

## Filosofía del proyecto

El objetivo no es instalar el máximo número posible de paquetes, sino utilizar las herramientas que tienen sentido en Debian Trixie 13 y evitar forzar componentes que puedan introducir conflictos de dependencias.

En particular, el instalador no convierte una instalación de Debian Trixie 13 en una instalación basada en paquetes de otra versión de Debian solo para obtener Wine.

## Seguridad

Los scripts deben ejecutarse como usuario normal, no como `root`.

Antes de ejecutar una limpieza destructiva:

```bash
./gaming/cleanup-gaming-debian-trixie.sh --dry-run
```

Revisa la lista que muestra el script antes de aceptar cualquier operación.

## Licencia

Añade aquí la licencia que corresponda al repositorio si todavía no está definida.
