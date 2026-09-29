# Manual de Gaming en Debian Trixie 13

## 1. Objetivo

Este proyecto prepara un entorno de gaming sobre Debian Trixie 13 utilizando Steam/Proton y herramientas complementarias.

La instalación está separada de la limpieza para que el usuario pueda:

- instalar el entorno;
- comprobarlo;
- conservar sus juegos;
- eliminar posteriormente los componentes añadidos por el proyecto.

## 2. Antes de empezar

Comprueba que el sistema es Debian Trixie 13 y que APT funciona correctamente.

No ejecutes los scripts como `root`.

La forma normal de trabajo es:

```bash
chmod +x gaming/setup-gaming-debian-trixie.sh
./gaming/setup-gaming-debian-trixie.sh
```

El instalador utiliza `sudo` cuando necesita modificar el sistema.

## 3. Qué instala o configura

El instalador puede trabajar con los siguientes componentes:

| Componente | Función |
|---|---|
| Steam | Plataforma principal para juegos |
| Proton | Compatibilidad Windows mediante Steam |
| ProtonPlus | Gestión de builds de Proton-GE |
| Protontricks | Workarounds para juegos ejecutados con Proton |
| Winetricks | Herramienta para prefijos Wine tradicionales |
| GameMode | Ajustes de rendimiento durante los juegos |
| MangoHud | Overlay de monitorización |
| MangoJuice | GUI para configurar MangoHud |
| Heroic | Lanzador de juegos compatible con varias tiendas |
| Lutris | Gestor de juegos y aplicaciones |
| Gamescope | Compositor/entorno para juegos |
| mesa-utils | Herramientas de diagnóstico gráfico |
| ntsync | Soporte del mecanismo utilizado por Wine/Proton cuando el kernel lo proporciona |

Algunos componentes son opcionales y el script puede preguntar antes de instalarlos.

## 4. Wine del sistema

El proyecto no obliga a instalar Wine del sistema.

Esto es importante porque el objetivo es mantener el sistema coherente con Debian Trixie 13 y evitar mezclar paquetes de otra suite para resolver una dependencia concreta.

Steam + Proton no necesita que exista un Wine global instalado para ejecutar juegos compatibles.

### Winetricks

Winetricks puede estar instalado aunque no exista `wine`/`wineserver`.

En ese caso:

```bash
winetricks
```

puede advertir:

```text
wineserver not found!
```

Ese comportamiento es coherente con la ausencia de Wine del sistema.

Winetricks será útil para prefijos Wine normales cuando exista un Wine funcional.

### Protontricks

Protontricks tiene otro propósito: aplicar acciones de Winetricks sobre juegos de Steam que utilizan Proton.

El proyecto instala Protontricks mediante `pipx` y añade su integración gráfica mediante:

```bash
protontricks-desktop-install
```

Después de instalarlo, el programa puede aparecer en el menú de aplicaciones.

Si Protontricks no muestra ningún juego, primero ejecuta al menos una vez un juego de Steam mediante Proton.

## 5. Steam

Steam es el componente principal para los juegos de Steam.

Después de instalarlo:

1. Abre Steam.
2. Instala un juego compatible con Proton.
3. Ejecuta el juego al menos una vez.
4. Cierra el juego.
5. Abre Protontricks.

Así Protontricks podrá detectar el juego y mostrar su AppID/prefijo correspondiente.

## 6. Proton-GE

ProtonPlus se utiliza para gestionar builds adicionales de Proton, especialmente Proton-GE.

El flujo recomendado es:

1. Abrir ProtonPlus.
2. Seleccionar Steam.
3. Instalar la build de Proton-GE que se necesite.
4. En Steam, abrir las propiedades del juego.
5. Seleccionar la versión de Proton deseada desde la compatibilidad.

No es necesario instalar Proton-GE para todos los juegos. Úsalo cuando un juego concreto lo necesite o cuando quieras probar otra build.

## 7. GameMode

GameMode permite que un juego solicite ajustes temporales orientados al rendimiento.

Comprobación básica:

```bash
gamemoderun true
```

Si el comando termina correctamente, GameMode responde.

En opciones de lanzamiento de Steam se puede utilizar, según el caso:

```text
gamemoderun %command%
```

## 8. MangoHud

MangoHud proporciona un overlay con información de rendimiento.

El proyecto puede compilarlo desde fuente para disponer de soporte NVML cuando corresponde a una GPU NVIDIA.

Una comprobación básica:

```bash
mangohud --version
```

El archivo de configuración se gestiona en:

```text
~/.config/MangoHud/
```

El instalador también puede configurar `pci_dev` para escenarios de GPU híbrida.

## 9. game-performance

El instalador proporciona:

```text
/usr/local/bin/game-performance
```

Su objetivo es envolver el lanzamiento de un juego para:

- guardar el perfil de energía anterior;
- activar `performance` si el sistema lo ofrece;
- inhibir temporalmente suspensión/salvapantallas cuando corresponde;
- ejecutar el juego;
- restaurar el perfil anterior al terminar.

Ejemplo:

```text
game-performance gamemoderun mangohud %command%
```

El wrapper no presupone que el perfil anterior fuese `balanced`; intenta restaurar el que estaba activo.

## 10. Gamescope y Backports

Si eliges Gamescope, el instalador comprueba `trixie-backports` y utiliza explícitamente:

```bash
sudo apt install -y -t trixie-backports gamescope
```

Si el instalador creó el fichero `/etc/apt/sources.list.d/debian-trixie-backports.sources`, la limpieza solo ofrece eliminarlo si conserva la marca del proyecto.

## 11. ntsync

El instalador configura la carga automática del módulo correspondiente mediante:

```text
/etc/modules-load.d/ntsync.conf
```

La limpieza puede retirar el archivo creado por el proyecto.

## 12. Comprobaciones

Después de instalar, comprueba los componentes principales:

```bash
steam
gamemoderun true
gamescope --version
mangohud --version
protontricks --version
winetricks --version
```

También puedes comprobar:

```bash
command -v game-performance
```

El resultado del instalador debe distinguir entre:

- componentes instalados correctamente;
- componentes opcionales;
- advertencias que no impiden utilizar Steam + Proton.

## 13. Repetir la instalación

El instalador está planteado para poder ejecutarse de nuevo.

Si un componente ya está instalado o una configuración ya existe, el script intenta detectarlo y evitar trabajo innecesario.

Esto permite utilizar el script también como herramienta de reparación básica de la configuración.

## 14. Limpieza

La limpieza se realiza con:

```bash
./gaming/cleanup-gaming-debian-trixie.sh --dry-run
```

Primero revisa la simulación.

Después:

```bash
./gaming/cleanup-gaming-debian-trixie.sh
```

El limpiador trabaja por bloques y pregunta antes de realizar las operaciones normales.

### Modo automático

```bash
./gaming/cleanup-gaming-debian-trixie.sh -y
```

`-y` acepta las confirmaciones normales, pero no convierte las operaciones destructivas de datos en automáticas.

### Borrado de datos

Para ofrecer el borrado de datos personales:

```bash
./gaming/cleanup-gaming-debian-trixie.sh --purge-data
```

El script muestra primero las carpetas encontradas y su tamaño aproximado.

Para confirmar el borrado solicita escribir:

```text
BORRAR
```

## 15. El problema del icono de Steam

Un caso habitual después de desinstalar Steam es que el programa desaparezca pero permanezca una entrada en el menú de aplicaciones.

Esto puede suceder si queda un archivo `.desktop` dentro del directorio de aplicaciones del usuario.

El limpiador comprueba:

```text
~/.local/share/applications/steam.desktop
~/.local/share/applications/steam-native.desktop
~/.local/share/applications/steam-url-handler.desktop
~/.local/share/applications/steam-launcher.desktop
```

Si encuentra alguno, lo muestra y ofrece eliminarlo.

Después puede actualizar la base de datos de aplicaciones del usuario.

### Importante

Esto no equivale a borrar Steam y todos sus juegos.

La eliminación de esos lanzadores no toca por sí sola:

```text
~/.steam
~/.local/share/Steam
~/Games
```

## 16. Datos que la limpieza protege

Sin `--purge-data`, el limpiador conserva los datos personales relacionados con los juegos.

Entre ellos:

```text
~/.steam
~/.local/share/Steam
~/Games
~/.config/heroic
~/.config/lutris
~/.local/share/lutris
~/.cache/lutris
~/.config/MangoHud
~/.config/goverlay
~/.config/protontricks
~/.cache/winetricks
~/.var/app/com.vysp3r.ProtonPlus
~/.var/app/io.github.radiolamp.mangojuice
~/.var/app/io.github.benjamimgois.goverlay
```

Con `--purge-data`, el script puede ofrecer eliminar las rutas encontradas.

## 17. Qué conserva el limpiador

La limpieza no pretende convertir el sistema en un Debian recién instalado.

Por diseño conserva componentes compartidos con otras aplicaciones, como:

- `power-profiles-daemon`;
- Flatpak;
- el remoto Flathub;
- arquitectura `i386`;
- paquetes de desarrollo que puedan tener otros usos.

También evita eliminar automáticamente archivos que no estén claramente identificados como pertenecientes a la configuración del proyecto.

## 18. Después de la limpieza

El script recomienda reiniciar si se han retirado configuraciones de kernel que estaban activas en la sesión.

Esto es relevante para valores que se aplicaron durante el funcionamiento del sistema: eliminar el archivo de configuración no necesariamente deshace inmediatamente el valor que ya está cargado en el kernel.

## 19. Diagnóstico

Si algo no funciona, primero ejecuta:

```bash
./gaming/setup-gaming-debian-trixie.sh
```

y revisa el resumen final.

Para la limpieza:

```bash
./gaming/cleanup-gaming-debian-trixie.sh --dry-run
```

La simulación permite comprobar qué detectaría el script sin realizar cambios.

## 20. Principio de seguridad

El proyecto intenta evitar operaciones destructivas silenciosas.

Especialmente:

- no se ejecuta como `root`;
- `--dry-run` no modifica el sistema;
- `-y` no confirma el borrado de datos personales;
- `--purge-data` requiere una confirmación adicional;
- se conservan deliberadamente los datos de juegos salvo confirmación explícita.

