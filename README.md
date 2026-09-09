# debian-trixie-setup

Scripts para preparar y mantener un sistema **Debian 13 (trixie)** con
KDE Plasma: repositorios, paquetes de desarrollo/multimedia/sistema,
microcode, zram, Firefox oficial de Mozilla, driver NVIDIA, y limpieza de
apps de KDE que no uses.

## Contenido

- **[`setup/`](setup/)** — `setup-debian-trixie.sh`, el script de
  instalación inicial. Ver [`setup/README.md`](setup/README.md) para el
  detalle completo de qué hace y qué instala.
- **[`cleanup/`](cleanup/)** — `cleanup-debian-trixie.sh`, elimina apps de
  KDE Plasma que Debian instala por defecto y muchos no usan. Ver
  [`cleanup/README.md`](cleanup/README.md) para el detalle.
- **[`MANUAL.md`](MANUAL.md)** — guía paso a paso desde cero (pensada para
  quien no esté familiarizado con la terminal): dejar `sudo` listo,
  descargar los scripts, darles permiso de ejecución y ejecutarlos.

## Inicio rápido

```bash
git clone https://github.com/csr79a/debian-trixie-setup.git
cd debian-trixie-setup

chmod +x setup/setup-debian-trixie.sh cleanup/cleanup-debian-trixie.sh

./setup/setup-debian-trixie.sh
```

Si es la primera vez que usas la terminal para algo así, empieza por
[`MANUAL.md`](MANUAL.md) en vez de por aquí.

## Licencia

MIT
