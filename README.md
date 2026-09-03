# debian-trixie-setup

Scripts de configuración para **Debian 13 (trixie) con KDE Plasma**: uno
para dejar el sistema listo tras una instalación limpia, y otro para
quitar aplicaciones de Plasma que Debian instala por defecto y que
muchos usuarios no llegan a usar.

Probados en máquina virtual antes de usarlos en un sistema real —
recomendación que se mantiene para cualquiera que los use.

---

## Contenido del repositorio

```
debian-trixie-setup/
├── setup/
│   ├── setup-debian-trixie.sh   ← instalación inicial
│   └── README.md                ← detalle completo de qué instala
├── cleanup/
│   ├── cleanup-debian-trixie.sh ← limpieza de apps no usadas
│   └── README.md                ← detalle completo de qué elimina
└── MANUAL.md                    ← guía paso a paso: sudo, permisos, cómo ejecutar
```

- **[`setup/`](setup/)** — repositorios (formato deb822), actualización del
  sistema, microcode según CPU, un set de paquetes de desarrollo /
  multimedia / sistema, y el remoto de Flathub.
- **[`cleanup/`](cleanup/)** — elimina, por grupos y con confirmación,
  aplicaciones como la suite PIM/Kontact (KMail, KOrganizer, Akregator,
  KAddressBook...), herramientas de accesibilidad, Konqueror o xterm.
- **[`MANUAL.md`](MANUAL.md)** — la guía más detallada: cómo dejar `sudo`
  listo, qué son los permisos de ejecución y cómo se corren los scripts
  desde cero, para quien no esté familiarizado con la terminal.

---

## Requisitos

- Debian 13 (trixie) — probado en esta versión.
- Entorno KDE Plasma (algunos paquetes de `setup/` son específicos de
  Plasma; el resto no depende de KDE).
- Usuario con acceso a `sudo` (ver la sección siguiente si no lo tienes).
- Conexión a internet.

---

## Clonar el repositorio

```bash
git clone https://github.com/csr79a/debian-trixie-setup.git
cd debian-trixie-setup
```

Si prefieres descargarlo sin `git` (por ejemplo desde la web, con
"Code → Download ZIP"), descomprime el archivo y entra a la carpeta
resultante de la misma forma con `cd`.

---

## Permisos de ejecución

Al clonar o descargar, es normal que los scripts **no** tengan permiso
de ejecución todavía — es una medida de seguridad de Linux, un `.sh` no
se ejecuta como programa solo por su extensión. Hay que dárselo:

```bash
chmod +x setup/setup-debian-trixie.sh
chmod +x cleanup/cleanup-debian-trixie.sh
```

Puedes comprobar que se aplicó con `ls -la setup cleanup`: debería
aparecer una `x` en los permisos de esos dos archivos (por ejemplo
`-rwxr-xr-x` o similar).

> Si vienes de descargar los archivos por otro medio (navegador, chat,
> USB...) en vez de clonar con `git`, es posible que además tengan
> permisos de lectura restringidos (`-rwx--x--x`, por ejemplo). No pasa
> nada: lo único que importa para ejecutarlos es que tengan la `x`
> activada — no hace falta que sean legibles por "otros" para que tú, su
> dueño, puedas correrlos.

---

## Cómo entrar a cada carpeta y ejecutar los scripts

```bash
# Instalación inicial
cd setup
./setup-debian-trixie.sh
cd ..

# Limpieza de apps no usadas (cuando quieras, no hace falta que sea el mismo día)
cd cleanup
./cleanup-debian-trixie.sh
cd ..
```

El `./` delante del nombre le dice a la terminal "ejecuta el archivo que
está en esta misma carpeta" — por seguridad, Linux no busca programas
automáticamente en la carpeta donde estás.

Ambos scripts piden tu contraseña de `sudo` cuando la necesitan (la de
tu usuario normal, no la de `root`), y por defecto son **interactivos**:
te preguntan `[y/N]` antes de cada paso importante.

---

## Opciones de cada script

### `setup-debian-trixie.sh`

| Opción | Qué hace |
|---|---|
| *(sin opciones)* | Modo interactivo: pregunta antes de cada paso relevante. |
| `-y`, `--yes` | Modo no interactivo: asume "sí" en todas las confirmaciones (también evita que `apt`/`debconf` se queden esperando input). |
| `-h`, `--help` | Muestra la ayuda y sale, sin tocar nada. |

### `cleanup-debian-trixie.sh`

| Opción | Qué hace |
|---|---|
| *(sin opciones)* | Modo interactivo: revisa y confirma cada grupo de paquetes por separado. |
| `-y`, `--yes` | Confirma automáticamente todos los grupos "seguros" (no incluye ImageMagick salvo que también uses `--imagemagick`). |
| `--purge` | Usa `apt purge` en vez de `apt remove` — borra también los ficheros de configuración de los paquetes eliminados. |
| `--imagemagick` | Evalúa además eliminar ImageMagick, mostrando antes qué otros paquetes dependen de él (`apt-cache rdepends`), por si algo más lo necesita. |
| `-h`, `--help` | Muestra la ayuda y sale, sin tocar nada. |

Para el detalle completo de qué paquetes toca cada grupo/opción, consulta
el README dentro de cada carpeta ([`setup/README.md`](setup/README.md),
[`cleanup/README.md`](cleanup/README.md)).

---

## Recomendación de uso

1. Lee el `MANUAL.md` si es la primera vez que usas la terminal en Linux
   para algo así (explica `sudo`, permisos y todo el flujo con más calma).
2. La primera vez que corras cada script, hazlo **sin** `-y`, leyendo lo
   que te pregunta y lo que `apt` te muestra antes de confirmar.
3. Prueba siempre primero en una máquina virtual antes de tocar tu
   sistema real, sobre todo con `cleanup-debian-trixie.sh`.

---

## Licencia

MIT — puedes usar, copiar, modificar y redistribuir estos scripts
libremente, manteniendo el aviso de copyright. Se entregan "tal cual",
sin garantías.
