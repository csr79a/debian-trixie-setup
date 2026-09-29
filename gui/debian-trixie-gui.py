#!/usr/bin/env python3
"""
Debian Trixie Setup — lanzador gráfico

El GUI orquesta los scripts del repositorio y los proyectos externos.
La ejecución se realiza en un terminal VTE integrado en esta misma ventana,
para conservar sudo, whiptail y cualquier otra interacción de terminal sin
abrir una ventana externa.
"""
from __future__ import annotations

import shlex
import shutil
import subprocess
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Vte", "2.91")

from gi.repository import GLib, Gtk, Vte


ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = Path.home() / ".local" / "share" / "debian-trixie-setup" / "components"

PROJECTS = {
    "nvidia": {
        "name": "NVIDIA",
        "url": "https://github.com/csr79a/nvidia-debian-setup.git",
        "dir": COMPONENTS / "nvidia-debian-setup",
        "script": "setup-nvidia-debian.sh",
        "description": "Instalador independiente del driver NVIDIA para Debian.",
    },
    "asus": {
        "name": "ASUS ROG",
        "url": "https://github.com/csr79a/asusctl-rogcontrol-debian.git",
        "dir": COMPONENTS / "asusctl-rogcontrol-debian",
        "script": "setup-asusctl-rogcontrol.sh",
        "description": "Instalador independiente de asusctl + rog-control-center.",
    },
}


class TrixieGUI(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(title="Debian Trixie Setup")
        self.set_default_size(1100, 700)
        self.set_size_request(820, 560)
        self.set_border_width(18)
        self.connect("destroy", self._on_destroy)

        self.terminal = Vte.Terminal()
        self.terminal.connect("child-exited", self._child_exited)
        self.terminal.set_scrollback_lines(10000)
        self.terminal.set_hexpand(True)
        self.terminal.set_vexpand(True)

        self.status = Gtk.Label(label="Listo.")
        self.status.set_xalign(0)
        self.sudo_authenticated = False
        self.pending_action = None
        self.sudo_timer_id = GLib.timeout_add_seconds(60, self._refresh_sudo)

        self._build()

    def _build(self) -> None:
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.add(root)

        title = Gtk.Label()
        title.set_markup("<span size='xx-large' weight='bold'>Debian Trixie Setup</span>")
        title.set_xalign(0)
        root.pack_start(title, False, False, 0)

        subtitle = Gtk.Label(label="Debian 13 · KDE Plasma · lanzador de componentes")
        subtitle.set_xalign(0)
        root.pack_start(subtitle, False, False, 0)

        cards = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        root.pack_start(cards, False, False, 0)

        self._card(
            cards,
            "Sistema Trixie",
            "Repositorios deb822, paquetes base, microcode, zram y Firefox oficial de Mozilla.",
            lambda: self.run_script(ROOT / "setup" / "setup-debian-trixie.sh"),
        )
        self._card(
            cards,
            "Limpieza",
            "Limpia aplicaciones KDE seleccionadas mediante el script independiente.",
            lambda: self.run_script(ROOT / "cleanup" / "cleanup-debian-trixie.sh"),
        )
        self._card(
            cards,
            "Gaming",
            "Steam/Proton, GameMode, MangoHud, Protontricks, Heroic, Lutris y Gamescope.",
            lambda: self.run_script(ROOT / "gaming" / "setup-gaming-debian-trixie.sh"),
        )
        self._card(
            cards,
            "NVIDIA",
            PROJECTS["nvidia"]["description"],
            lambda: self.external("nvidia"),
        )
        self._card(
            cards,
            "ASUS ROG",
            PROJECTS["asus"]["description"],
            lambda: self.external("asus"),
        )

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        root.pack_start(actions, False, False, 0)

        update = Gtk.Button(label="Actualizar componentes externos")
        update.connect("clicked", lambda _button: self.update_all())
        actions.pack_start(update, False, False, 0)

        folder = Gtk.Button(label="Abrir carpeta de componentes")
        folder.connect("clicked", lambda _button: self.open_components())
        actions.pack_start(folder, False, False, 0)

        clear = Gtk.Button(label="Limpiar terminal")
        clear.connect("clicked", lambda _button: self.terminal.reset(True, True))
        actions.pack_start(clear, False, False, 0)

        close = Gtk.Button(label="Cerrar")
        close.connect("clicked", lambda _button: self.destroy())
        actions.pack_end(close, False, False, 0)

        auth_frame = Gtk.Frame(label="Autenticación sudo")
        auth_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        auth_box.set_border_width(8)
        auth_frame.add(auth_box)

        auth_label = Gtk.Label(label="Contraseña:")
        auth_box.pack_start(auth_label, False, False, 0)

        self.password_entry = Gtk.Entry()
        self.password_entry.set_visibility(False)
        self.password_entry.set_placeholder_text("Contraseña de sudo")
        self.password_entry.set_hexpand(True)
        self.password_entry.connect("activate", lambda _entry: self.authenticate_sudo())
        auth_box.pack_start(self.password_entry, True, True, 0)

        auth_button = Gtk.Button(label="Autenticar")
        auth_button.connect("clicked", lambda _button: self.authenticate_sudo())
        auth_box.pack_start(auth_button, False, False, 0)

        root.pack_start(auth_frame, False, False, 0)
        root.pack_start(self.status, False, False, 0)

        terminal_frame = Gtk.Frame(label="Terminal integrada")
        terminal_frame.set_shadow_type(Gtk.ShadowType.IN)
        terminal_frame.add(self.terminal)
        root.pack_start(terminal_frame, True, True, 0)

        self._write(
            "Listo. Pulsa un botón: el instalador se ejecutará aquí mismo, "
            "dentro de esta ventana, sin abrir otra terminal.\n"
        )

    def _card(self, parent, title: str, description: str, command) -> None:
        frame = Gtk.Frame()
        frame.set_label(title)
        frame.set_margin_left(2)
        frame.set_margin_right(2)
        frame.set_margin_top(2)
        frame.set_margin_bottom(2)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_border_width(10)
        frame.add(box)

        label = Gtk.Label(label=description)
        label.set_line_wrap(True)
        label.set_max_width_chars(24)
        label.set_xalign(0)
        box.pack_start(label, True, True, 0)

        button = Gtk.Button(label="Ejecutar")
        button.connect("clicked", lambda _button: command())
        box.pack_end(button, False, False, 0)

        parent.pack_start(frame, True, True, 0)

    def _on_destroy(self, _widget) -> None:
        if self.sudo_timer_id:
            GLib.source_remove(self.sudo_timer_id)
            self.sudo_timer_id = 0
        Gtk.main_quit()

    def authenticate_sudo(self) -> None:
        password = self.password_entry.get_text()
        self.password_entry.set_text("")

        if not password:
            self.status.set_text("Introduce la contraseña de sudo.")
            return

        try:
            result = subprocess.run(
                ["sudo", "-S", "-v"],
                input=password + "\n",
                text=True,
                capture_output=True,
                timeout=30,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            self.sudo_authenticated = False
            self.status.set_text(f"No se pudo autenticar sudo: {exc}")
            return
        finally:
            password = ""

        if result.returncode == 0:
            self.sudo_authenticated = True
            self.status.set_text("Sudo autenticado. Ejecutando la acción solicitada…")
            self._write("\n[OK] Autenticación sudo correcta.\n")
            action = self.pending_action
            self.pending_action = None
            if action is not None:
                GLib.idle_add(action)
        else:
            self.sudo_authenticated = False
            self.status.set_text("Contraseña de sudo incorrecta o sudo rechazó la autenticación.")
            self._write("\n[ERROR] No se pudo autenticar sudo.\n")

    def _refresh_sudo(self) -> bool:
        if not self.sudo_authenticated:
            return True

        try:
            result = subprocess.run(
                ["sudo", "-n", "-v"],
                text=True,
                capture_output=True,
                timeout=10,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return True

        if result.returncode != 0:
            self.sudo_authenticated = False
            self.status.set_text("La autenticación sudo ha expirado. Vuelve a autenticarte.")
        return True

    def _ensure_sudo(self, action=None) -> bool:
        if self.sudo_authenticated:
            result = subprocess.run(
                ["sudo", "-n", "-v"],
                text=True,
                capture_output=True,
                timeout=10,
                check=False,
            )
            if result.returncode == 0:
                return True

        self.sudo_authenticated = False
        self.pending_action = action
        self.status.set_text("Introduce la contraseña de sudo y pulsa «Autenticar».")
        self.password_entry.grab_focus()
        return False

    def _write(self, text: str) -> None:
        self.terminal.feed(text.encode("utf-8"))

    def _spawn(self, command: str, cwd: Path) -> None:
        argv = ["/bin/bash", "-lc", command]
        self.terminal.spawn_async(
            Vte.PtyFlags.DEFAULT,
            str(cwd),
            argv,
            None,
            GLib.SpawnFlags.DEFAULT,
            None,
            None,
            -1,
            None,
            self._spawn_finished,
            None,
        )

    def _spawn_finished(self, _terminal, _pid, error, _user_data) -> None:
        if error is not None:
            self.status.set_text(f"No se pudo iniciar el proceso: {error}")

    def _child_exited(self, _terminal, status: int, _user_data) -> None:
        if status == 0:
            self.status.set_text("Finalizado correctamente.")
        else:
            self.status.set_text(f"El proceso terminó con código {status}.")

    def run_script(self, script: Path) -> None:
        if not self._ensure_sudo(lambda: self.run_script(script)):
            return

        if not script.is_file():
            self._write(f"\n[ERROR] Archivo no encontrado: {script}\n")
            self.status.set_text("Archivo no encontrado.")
            return

        self._write(f"\n$ bash {script.name}\n")
        self.status.set_text(f"Ejecutando {script.name}…")
        self._spawn(f"exec bash {shlex.quote(script.name)}", script.parent)

    def external(self, key: str) -> None:
        if not self._ensure_sudo(lambda: self.external(key)):
            return

        if not shutil.which("git"):
            self._write("\n[ERROR] Git no está instalado.\n")
            self.status.set_text("Git no está instalado.")
            return

        p = PROJECTS[key]
        dest = Path(p["dir"])
        COMPONENTS.mkdir(parents=True, exist_ok=True)

        if (dest / ".git").is_dir():
            command = (
                f"git -C {shlex.quote(str(dest))} pull --ff-only && "
                f"exec bash {shlex.quote(str(dest / p['script']))}"
            )
        else:
            command = (
                f"git clone {shlex.quote(p['url'])} {shlex.quote(str(dest))} && "
                f"exec bash {shlex.quote(str(dest / p['script']))}"
            )

        self._write(f"\n$ {p['name']}\n")
        self.status.set_text(f"Preparando {p['name']}…")
        self._spawn(command, COMPONENTS)

    def update_all(self) -> None:
        if not shutil.which("git"):
            self._write("\n[ERROR] Git no está instalado.\n")
            self.status.set_text("Git no está instalado.")
            return

        commands = []
        for key, p in PROJECTS.items():
            dest = Path(p["dir"])
            if (dest / ".git").is_dir():
                commands.append(
                    f"echo '=== Actualizando {p['name']} ==='; "
                    f"git -C {shlex.quote(str(dest))} pull --ff-only"
                )
            else:
                COMPONENTS.mkdir(parents=True, exist_ok=True)
                commands.append(
                    f"echo '=== Clonando {p['name']} ==='; "
                    f"git clone {shlex.quote(p['url'])} {shlex.quote(str(dest))}"
                )

        command = " && ".join(commands) if commands else "true"
        self._write("\n$ Actualizando componentes externos…\n")
        self.status.set_text("Actualizando componentes externos…")
        self._spawn(command, COMPONENTS)

    def open_components(self) -> None:
        COMPONENTS.mkdir(parents=True, exist_ok=True)
        opener = shutil.which("xdg-open")
        if opener:
            subprocess.Popen([opener, str(COMPONENTS)])
        else:
            self._write(f"\nCarpeta: {COMPONENTS}\n")


if __name__ == "__main__":
    win = TrixieGUI()
    win.show_all()
    Gtk.main()
