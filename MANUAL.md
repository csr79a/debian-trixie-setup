# Manual — Scripts de configuración para Debian 13 (trixie)

Este manual explica, paso a paso y desde cero, cómo preparar tu sistema y
ejecutar los dos scripts de este proyecto:

- **`setup-debian-trixie.sh`** — configura repos, actualiza el sistema e
  instala un set de paquetes de desarrollo/multimedia/sistema. Ver
  `README-setup.md` para el detalle de qué instala.
- **`cleanup-debian-trixie.sh`** — elimina aplicaciones de KDE Plasma que
  no usas. Ver `README-cleanup.md` para el detalle de qué elimina.

No hace falta que sepas bash para seguir estos pasos.

---

## 1. Antes de nada: deja `sudo` listo

Ambos scripts usan `sudo` para las tareas que requieren privilegios de
administrador (instalar/quitar paquetes, escribir en `/etc`). Debian **no**
siempre configura `sudo` automáticamente:

- Si al instalar Debian **dejaste en blanco** la contraseña de `root`,
  `sudo` ya debería estar listo para tu usuario.
- Si le **pusiste contraseña a `root`** (lo más habitual), Debian no
  instala `sudo` ni añade tu usuario a ningún grupo, aunque hayas
  instalado el escritorio completo con KDE Plasma.

Para comprobarlo, abre una terminal (Konsole) y ejecuta:

```bash
sudo -v
```

- Si te pide **tu contraseña de usuario** (no la de root) y no da error,
  ya está listo — puedes saltarte el resto de esta sección.
- Si da error de tipo *"sudo: command not found"* o *"no está en el
  fichero sudoers"*, sigue estos pasos una única vez:

```bash
# 1. Entra como root (te pedirá la contraseña de root)
su -

# 2. Instala sudo
apt update
apt install sudo

# 3. Añade tu usuario normal al grupo sudo (sustituye TU_USUARIO)
usermod -aG sudo TU_USUARIO

# 4. Sal de la sesión de root
exit
```

Después, **cierra sesión y vuelve a entrar** (o reinicia) para que el
cambio de grupo se aplique, y confirma con `groups` que `sudo` aparece en
la lista.

Ambos scripts comprueban esto por ti al arrancar (existencia de `sudo` y
`sudo -v`) y se detienen con un mensaje claro si algo falta, en vez de
fallar a mitad de instalación.

---

## 2. Descargar/copiar los scripts y darles permiso de ejecución

Los archivos que necesitas están en esta misma entrega:

```
setup-debian-trixie.sh
README-setup.md
cleanup-debian-trixie.sh
README-cleanup.md
MANUAL.md   (este archivo)
```

Cópialos a una carpeta de tu sistema, por ejemplo:

```bash
mkdir -p ~/Proyectos/debian-trixie-setup
cd ~/Proyectos/debian-trixie-setup
# copia aquí los archivos (USB, git clone, scp, lo que uses)
```

Por defecto, los archivos que copies **no tienen permiso de ejecución** —
es una medida de seguridad de Linux: un `.sh` no se ejecuta como programa
solo por tener esa extensión. Hay que dárselo explícitamente:

```bash
chmod +x setup-debian-trixie.sh
chmod +x cleanup-debian-trixie.sh
```

`chmod +x` añade el permiso "ejecutable" (execute) al archivo, para tu
usuario, el grupo y otros. Puedes comprobar que se aplicó con:

```bash
ls -l setup-debian-trixie.sh
# -rwxr-xr-x ...   ← las "x" indican que ya es ejecutable
```

---

## 3. Ejecutar los scripts

Siempre desde la carpeta donde están (o indicando la ruta), **nunca como
root directamente**:

```bash
# Instalación inicial del sistema
./setup-debian-trixie.sh

# Limpieza de apps de KDE que no usas (ejecútalo después, cuando quieras)
./cleanup-debian-trixie.sh
```

El `./` al principio le dice a la terminal "ejecuta el archivo que está
aquí, en esta carpeta" (por seguridad, Linux no busca automáticamente
programas en la carpeta actual).

Los dos scripts son **interactivos por defecto**: te van preguntando
antes de cada paso importante (`[y/N]` — escribe `y` y Enter para
confirmar, cualquier otra cosa o Enter vacío para rechazar). Cuando
`sudo` necesite tu contraseña, te la pedirá en el momento; es tu
contraseña de usuario normal, no la de `root`.

### Modo no interactivo (`-y`)

Si ya revisaste el script y confías en él, puedes saltarte todas las
confirmaciones con `-y`:

```bash
./setup-debian-trixie.sh -y
./cleanup-debian-trixie.sh -y
```

**Recomendación:** la primera vez que uses cada script, hazlo sin `-y`,
lee lo que te va preguntando y lo que `apt` te muestra antes de aceptar.
Una vez que confías en que hace lo que esperas en tu sistema, ya puedes
usar `-y` en ejecuciones futuras (por ejemplo, tras una reinstalación
limpia).

### Ayuda

Ambos scripts aceptan `-h`/`--help` para ver un resumen rápido de sus
opciones sin ejecutar nada:

```bash
./setup-debian-trixie.sh -h
./cleanup-debian-trixie.sh -h
```

---

## 4. Orden recomendado

1. Deja `sudo` listo (paso 1).
2. Ejecuta `setup-debian-trixie.sh` en un sistema recién instalado, para
   partir de repos y paquetes base consistentes.
3. Cuando lleves un tiempo usando el sistema y tengas claro qué apps de
   KDE no usas, ejecuta `cleanup-debian-trixie.sh`.
4. Prueba siempre primero en una máquina virtual si vas a cambiar algo
   del script o no estás seguro de qué se va a eliminar — es lo que ya
   vienes haciendo y es la forma correcta de validarlo sin riesgo.

---

## 5. Si algo sale mal

- Los mensajes de error de estos scripts están pensados para decirte
  **qué revisar** (normalmente, este manual o el README correspondiente).
- `apt` nunca elimina nada sin mostrarte antes el resumen completo de la
  transacción (a menos que uses `-y`), así que siempre puedes cancelar
  con `Ctrl+C` o respondiendo que no, antes de que se aplique.
- Ninguno de los dos scripts es destructivo de forma irreversible: los
  paquetes se pueden reinstalar (`sudo apt install <paquete>`) y, si
  usaste `apt remove` en vez de `--purge`, tu configuración debería
  seguir intacta.
