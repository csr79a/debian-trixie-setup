# Lanzador gráfico de Debian Trixie

El directorio `gui/` contiene el lanzador gráfico del proyecto.

## Qué hace

El GUI es un **orquestador**, no duplica la lógica de los instaladores. Los componentes locales son Sistema Trixie, Gaming y Limpieza; NVIDIA y ASUS ROG siguen siendo proyectos externos:

- **Sistema Trixie** → `setup/setup-debian-trixie.sh`
- **Gaming** → `gaming/setup-gaming-debian-trixie.sh`
- **Limpieza** → `cleanup/cleanup-debian-trixie.sh`
- **NVIDIA** → `csr79a/nvidia-debian-setup`
- **ASUS ROG** → `csr79a/asusctl-rogcontrol-debian`

Los componentes externos se descargan/actualizan en:

`~/.local/share/debian-trixie-setup/components/`

Los scripts se ejecutan en un **terminal VTE integrado dentro de la propia ventana del GUI**. Así se conservan `sudo`, `whiptail` y cualquier interacción necesaria sin abrir una segunda ventana de terminal.

## Instalar el lanzador

Desde la raíz del repositorio:

```bash
chmod +x gui/instalar-lanzador.sh
./gui/instalar-lanzador.sh
```

Después aparecerá **Debian Trixie Setup** en el menú de aplicaciones de KDE.

## Dependencias

- Python 3
- GTK 3 (`gir1.2-gtk-3.0`)
- PyGObject (`python3-gi`)
- VTE 2.91 (`gir1.2-vte-2.91`)
- Git

No es necesario instalar Konsole ni otro emulador de terminal para ejecutar los instaladores desde el GUI.
