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

## GUI Qt

La aplicación usa **PyQt6** y mantiene un **único pseudo-terminal (PTY)** dentro de la ventana.

Esto permite que `sudo`, `read` y otras preguntas interactivas se comporten como en un terminal real. La salida del script se muestra en la ventana y el campo inferior permite enviar respuestas.

La contraseña de `sudo` no se almacena en un archivo ni se escribe deliberadamente en el historial del shell. Cuando la salida del script parece solicitar una contraseña, el campo cambia temporalmente a modo oculto.

El lanzador incluye un shim propio de `whiptail` para las cajas simples `--yesno`, `--msgbox` e `--infobox`. Los menús, listas, campos de entrada y otros diálogos que no puede representar el shim se ejecutan en **Konsole**.

## Instalar el lanzador

Desde la raíz del repositorio:

```bash
chmod +x gui/instalar-lanzador.sh
./gui/instalar-lanzador.sh
```

Después aparecerá **Debian Trixie Setup** en el menú de aplicaciones de KDE.

## Dependencias

El instalador comprueba e instala automáticamente:

- Python 3
- `python3-pyqt6`
- Git

**Konsole** o `x-terminal-emulator` solo son necesarios cuando un script necesita una interfaz de terminal que el modo integrado no puede representar, por ejemplo menús o listas de `whiptail`/`dialog`.

## Ejecución directa

También puedes comprobar el GUI directamente:

```bash
python3 -m py_compile gui/debian-trixie-gui.py
python3 gui/debian-trixie-gui.py
```

La aplicación debe ejecutarse como usuario normal, no como root. Los scripts solicitan `sudo` cuando necesitan privilegios.

## Comportamiento de las acciones

- **Sistema** y **Gaming** son acciones locales: ejecutan directamente los scripts incluidos en este repositorio.
- **NVIDIA** y **ASUS ROG** son acciones remotas: clonan o actualizan sus repositorios en `~/.local/share/debian-trixie-setup/components/` antes de ejecutar el script indicado.
- Las acciones marcadas como peligrosas muestran una confirmación antes de ejecutarse.
- El instalador verifica la sintaxis del GUI con `python3 -m py_compile` antes de crear el `.desktop`.
