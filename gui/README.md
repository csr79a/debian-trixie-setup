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

Esto es importante para `sudo`: la autenticación se realiza dentro del mismo PTY que posteriormente utilizan los scripts. De esta forma, la credencial temporal de sudo pertenece al mismo terminal y los comandos `sudo` de los instaladores pueden reutilizarla.

La ventana incluye abajo:

- campo gráfico **Contraseña de sudo**;
- botón **Autenticar**;
- terminal integrada;
- botones para Sistema, Limpieza, Gaming, NVIDIA y ASUS ROG.

La contraseña no se guarda en un archivo ni se escribe deliberadamente en el historial del shell. El campo se limpia inmediatamente después de pulsar **Autenticar**.

El terminal integrado conserva la interacción de los scripts, incluidos `sudo`, `whiptail` y las preguntas normales de los instaladores.

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
- `python3-pyte`
- Git

No se necesita GTK, VTE, Konsole ni otro emulador de terminal externo.

## Ejecución directa

También puedes comprobar el GUI directamente:

```bash
python3 -m py_compile gui/debian-trixie-gui.py
python3 gui/debian-trixie-gui.py
```

La aplicación debe ejecutarse como usuario normal, no como root.
