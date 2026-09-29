# Lanzador gráfico de Debian Trixie

El directorio `gui/` contiene el lanzador gráfico del proyecto.

## Qué hace

El GUI es un **orquestador**, no duplica la lógica de los instaladores:

- **Sistema Trixie** → `setup/setup-debian-trixie.sh`
- **Limpieza** → `cleanup/cleanup-debian-trixie.sh`
- **NVIDIA** → `csr79a/nvidia-debian-setup`
- **ASUS ROG** → `csr79a/asusctl-rogcontrol-debian`

Los componentes externos se descargan/actualizan en:

`~/.local/share/debian-trixie-setup/components/`

Los scripts se abren en una terminal real para conservar sus preguntas de sudo,
whiptail y cualquier interacción necesaria.

## Instalar el lanzador

Desde la raíz del repositorio:

```bash
chmod +x gui/instalar-lanzador.sh
./gui/instalar-lanzador.sh
```

Después aparecerá **Debian Trixie Setup** en el menú de aplicaciones de KDE.

## Dependencias

- Python 3
- Tkinter (`python3-tk`)
- Git
- Un emulador de terminal, preferentemente Konsole en KDE.
