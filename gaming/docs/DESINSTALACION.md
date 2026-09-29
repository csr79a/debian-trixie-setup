# Desinstalación y limpieza

## 1. Simulación recomendada

Antes de borrar nada:

```bash
chmod +x gaming/cleanup-gaming-debian-trixie.sh
./gaming/cleanup-gaming-debian-trixie.sh --dry-run
```

Este modo muestra lo que detectaría el script sin modificar el sistema.

## 2. Limpieza interactiva

```bash
./gaming/cleanup-gaming-debian-trixie.sh
```

El script pregunta por cada bloque.

## 3. Aceptar operaciones normales

```bash
./gaming/cleanup-gaming-debian-trixie.sh -y
```

`-y` acepta las confirmaciones normales.

No autoriza automáticamente:

- el borrado de datos personales;
- `autoremove`;
- determinados cambios adicionales que el script considera sensibles.

## 4. Borrado de datos

```bash
./gaming/cleanup-gaming-debian-trixie.sh --purge-data
```

El script primero muestra las rutas encontradas y su tamaño.

Solo continúa con el borrado de datos si se confirma escribiendo:

```text
BORRAR
```

Este borrado puede incluir juegos instalados, prefijos Proton y otros datos locales.

## 5. Paquetes

La limpieza contempla los paquetes APT relacionados con el proyecto, incluyendo:

```text
steam-installer
steam-launcher
heroic
gamemode
winetricks
mesa-utils
lutris
gamescope
```

**Protontricks no es un paquete APT en este proyecto**: se instala mediante `pipx` y se desinstala mediante `pipx uninstall protontricks`.

Solo se purgan si están presentes.

## 6. Steam: icono que queda en el menú

El limpiador tiene un paso específico para lanzadores de Steam.

Busca:

```text
~/.local/share/applications/steam.desktop
~/.local/share/applications/steam-native.desktop
~/.local/share/applications/steam-url-handler.desktop
~/.local/share/applications/steam-launcher.desktop
```

Si encuentra alguno:

1. muestra los archivos;
2. indica que son lanzadores de usuario;
3. solicita confirmación;
4. los elimina si se acepta;
5. intenta actualizar la base de datos de aplicaciones del usuario.

Esto está pensado precisamente para el caso en que Steam ya no funcione pero su icono siga apareciendo en el menú.

## 7. Datos que NO se borran por defecto

Sin `--purge-data`, se conservan los datos personales de juegos.

Por ejemplo:

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

## 8. Componentes compartidos que se conservan

La limpieza no elimina deliberadamente:

- `power-profiles-daemon`;
- Flatpak;
- Flathub;
- la arquitectura `i386`;
- paquetes de desarrollo.

Estos componentes pueden ser utilizados por otras aplicaciones.

## 9. Protontricks (pipx)

En Trixie Protontricks no se trata como paquete APT. El instalador lo coloca mediante `pipx` y también instala su integración gráfica.

La limpieza elimina Protontricks con:

```bash
pipx uninstall protontricks
```

y ofrece quitar sus lanzadores `.desktop` de usuario.

## 10. MangoHud

El script puede retirar la instalación de MangoHud compilada por el instalador cuando reconoce las rutas correspondientes y comprueba que no pertenecen a paquetes de Debian.

## 11. Configuración del sistema

El limpiador puede retirar los archivos de configuración creados por el proyecto, incluyendo:

```text
/usr/local/bin/game-performance
/etc/sysctl.d/80-gamecompatibility.conf
/etc/modules-load.d/ntsync.conf
~/.config/gamemode.ini
```

También puede ofrecer retirar la configuración específica de `pci_dev` y la configuración de `deb-src` utilizada para compilar MangoHud.

## 12. wineserver

Si existe un enlace:

```text
/usr/local/bin/wineserver
```

el script solo ofrece eliminarlo cuando puede comprobar que apunta al `wineserver` correspondiente.

## 13. Reinicio

Después de la limpieza se recomienda reiniciar si se han eliminado configuraciones relacionadas con valores del kernel que pudieron quedar activos durante la sesión.

## 14. Verificación final

Se puede comprobar que no quedan los paquetes principales con:

```bash
dpkg -l | grep -Ei 'steam|heroic|gamemode|winetricks|protontricks|lutris|gamescope'
```

El resultado debe interpretarse teniendo en cuenta que pueden aparecer otros paquetes o restos de configuración que no pertenezcan directamente al proyecto.
