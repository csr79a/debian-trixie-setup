# debian-trixie-setup

Scripts y lanzador gráfico para preparar y mantener un sistema **Debian 13 (trixie)** con KDE Plasma.

El proyecto separa el sistema base de los componentes de hardware externos: el setup principal no instala drivers NVIDIA ni asusctl. El lanzador gráfico los integra desde sus proyectos independientes.

## Componentes

- **Sistema Trixie** — [`setup/`](setup/): repositorios oficiales en formato deb822, actualización, paquetes base, microcode, zram y Firefox oficial de Mozilla.
- **Limpieza** — [`cleanup/`](cleanup/): elimina aplicaciones KDE seleccionadas mediante un script independiente.
- **GUI** — [`gui/`](gui/): lanzador gráfico que orquesta los componentes.
- **NVIDIA** — [`csr79a/nvidia-debian-setup`](https://github.com/csr79a/nvidia-debian-setup): proyecto independiente invocado por el GUI.
- **ASUS ROG** — [`csr79a/asusctl-rogcontrol-debian`](https://github.com/csr79a/asusctl-rogcontrol-debian): proyecto independiente para asusctl + rog-control-center.

## Inicio rápido

```bash
git clone https://github.com/csr79a/debian-trixie-setup.git
cd debian-trixie-setup

chmod +x gui/instalar-lanzador.sh
./gui/instalar-lanzador.sh
```

Después encontrarás **Debian Trixie Setup** en el menú de aplicaciones de KDE.

También puedes ejecutar los scripts directamente:

```bash
chmod +x setup/setup-debian-trixie.sh cleanup/cleanup-debian-trixie.sh

./setup/setup-debian-trixie.sh
./cleanup/cleanup-debian-trixie.sh
```

El lanzador descarga/actualiza los proyectos NVIDIA y ASUS en:

```text
~/.local/share/debian-trixie-setup/components/
```

Los instaladores de hardware se mantienen en sus propios repositorios para que cada proyecto pueda evolucionar y desinstalarse de forma independiente.

## Firefox oficial de Mozilla

El setup de Trixie conserva el flujo seguro del proyecto de referencia: verifica la clave y su huella digital, configura el repositorio oficial de Mozilla en formato deb822, instala Firefox **antes** de eliminar Firefox ESR y solo purga ESR/perfiles si la instalación de Firefox ha terminado correctamente.

## Documentación

- [`setup/README.md`](setup/README.md) — detalle del setup de Trixie.
- [`cleanup/README.md`](cleanup/README.md) — detalle de la limpieza.
- [`gui/README.md`](gui/README.md) — lanzador gráfico.
- [`MANUAL.md`](MANUAL.md) — guía desde cero.

## Licencia

MIT