# cleanup-debian-trixie.sh

Elimina aplicaciones de **KDE Plasma** que Debian 13 (trixie) instala por
defecto junto a la tarea de escritorio, pero que muchos usuarios no llegan
a usar (suite PIM/Kontact, algunas herramientas de accesibilidad,
Konqueror). Es el complemento de `setup-debian-trixie.sh`: ese script
instala, este quita.

---

## Índice

- [Qué hace](#qué-hace)
- [Por qué es un script aparte](#por-qué-es-un-script-aparte)
- [Uso](#uso)
- [Grupos y qué incluye cada uno](#grupos-y-qué-incluye-cada-uno)
- [Sobre ImageMagick](#sobre-imagemagick)
- [remove vs. purge](#remove-vs-purge)
- [Cómo revertirlo](#cómo-revertirlo)
- [Idempotencia](#idempotencia)
- [Licencia](#licencia)

---

## Qué hace

El script revisa, **grupo por grupo**, un conjunto de paquetes:

1. Comprueba qué paquetes de ese grupo están realmente instalados (si
   ninguno lo está, pasa al siguiente grupo sin preguntar nada).
2. Te muestra la lista y pide confirmación específica de ese grupo.
3. Si confirmas, ejecuta `apt remove` (o `apt purge` con `--purge`) —
   y salvo que uses `-y`, es el propio `apt` quien te enseña el resumen
   real de la transacción (incluyendo cualquier dependencia que se lleve
   por delante) antes de aplicar nada.
4. Al final, opcionalmente, ejecuta `apt autoremove` para limpiar
   paquetes huérfanos que hayan quedado sueltos.

## Por qué es un script aparte

`setup-debian-trixie.sh` está pensado para *añadir* software de forma
predecible. Eliminar paquetes es una operación de naturaleza distinta:
la lista de "qué se lleva por delante" depende del estado de cada
sistema, y mezclar instalación y desinstalación en un mismo script hace
más peligroso volver a ejecutarlo en una máquina donde sí usas alguna de
estas apps. Por eso van separados.

## Uso

```bash
chmod +x cleanup-debian-trixie.sh

# Modo interactivo (recomendado la primera vez): confirma cada grupo
./cleanup-debian-trixie.sh

# Modo no interactivo: confirma automáticamente los grupos "seguros"
./cleanup-debian-trixie.sh -y

# Igual que el anterior, pero borrando también los ficheros de configuración
./cleanup-debian-trixie.sh -y --purge

# Además, evalúa (con aviso) eliminar ImageMagick
./cleanup-debian-trixie.sh --imagemagick

# Ayuda
./cleanup-debian-trixie.sh -h
```

> Igual que en `setup-debian-trixie.sh`: no lo ejecutes con
> `curl ... | bash` sin `-y`, porque las confirmaciones necesitan una
> entrada de terminal interactiva.

## Grupos y qué incluye cada uno

| Grupo | Paquetes | Notas |
|---|---|---|
| Suite PIM / Kontact | `kmail`, `kaddressbook`, `ktnef`, `kdepim-themeeditors`, `pim-sieve-editor`, `pim-data-exporter` | Todos comparten árbol de dependencias con Akonadi. `ktnef` es un paquete de transición que hoy en día vive dentro de `kmail`. `kdepim-themeeditors` es el paquete real detrás de "Editor de temas de Contact" **y** "Editor de temas de encabezados de KMail" — por eso una sola entrada cubre dos de las apps que mencionaste. |
| Accesibilidad | `kmousetool`, `kmouth`, `kontrast` | Independientes del grupo PIM: **no** se eliminan solos al quitar KMail, por eso van en grupo aparte. |
| Konqueror | `konqueror` | Navegador/gestor de archivos histórico de KDE, sin relación con los otros grupos. |
| ImageMagick (opcional, `--imagemagick`) | `imagemagick` | Ver aviso abajo. |

Los nombres de paquete están verificados contra el repositorio de Debian
13 (trixie); aun así, antes de confirmar cada grupo el script te enseña
exactamente qué hay instalado, así que siempre tienes la última palabra.

## Sobre ImageMagick

**No es una aplicación de Plasma.** Es una utilidad/librería de línea de
comandos que otros programas pueden usar por debajo (miniaturas,
importación/exportación de imágenes desde otras apps, scripts, etc.).
Por eso:

- No se evalúa a menos que pases `--imagemagick` explícitamente.
- Cuando se evalúa, el script primero ejecuta
  `apt-cache rdepends imagemagick` y te enseña qué depende de él **antes**
  de pedir confirmación.

Si tienes dudas, dile que no cuando te pregunte y revisa el listado de
`rdepends` con calma en otro momento.

## remove vs. purge

- **`apt remove`** (por defecto): desinstala el paquete pero deja los
  ficheros de configuración en `/etc` y en tu `$HOME` (por si algún día
  reinstalas y quieres recuperar tu configuración).
- **`apt purge`** (con `--purge`): además borra esos ficheros de
  configuración. Solo recomendable si tienes claro que no vas a volver a
  usar esa app.

## Cómo revertirlo

Si más adelante echas en falta alguna de estas apps, se reinstala como
cualquier otro paquete:

```bash
sudo apt install kmail   # o el paquete que corresponda
```

Si usaste `apt remove` (no `--purge`), tu configuración anterior debería
seguir ahí.

## Idempotencia

Se puede volver a ejecutar sin problema: cada grupo comprueba primero qué
está instalado, así que si ya quitaste algo, el script simplemente te
dirá "nada que hacer" para ese grupo y seguirá con el siguiente.

## Licencia

MIT
