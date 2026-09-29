#!/usr/bin/env python3
"""
Debian Trixie Setup — lanzador gráfico

El GUI no duplica la lógica de instalación: orquesta los scripts de este
repositorio y los proyectos externos NVIDIA/ASUS. Los scripts se ejecutan
en una terminal real para conservar sudo, whiptail y cualquier interacción.
"""
from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

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


class TrixieGUI(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Debian Trixie Setup")
        self.geometry("900x620")
        self.minsize(760, 520)

        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass

        self.configure(padx=18, pady=18)
        self._build()

    def _build(self) -> None:
        header = ttk.Frame(self)
        header.pack(fill="x", pady=(0, 14))

        ttk.Label(
            header, text="Debian Trixie Setup",
            font=("Sans", 22, "bold")
        ).pack(anchor="w")
        ttk.Label(
            header,
            text="Debian 13 · KDE Plasma · lanzador de componentes",
            font=("Sans", 10)
        ).pack(anchor="w", pady=(2, 0))

        cards = ttk.Frame(self)
        cards.pack(fill="x", pady=(0, 14))

        self._card(
            cards, 0, "Sistema Trixie",
            "Repositorios deb822, paquetes base, microcode, zram y Firefox oficial de Mozilla.",
            lambda: self.run_terminal(ROOT / "setup" / "setup-debian-trixie.sh"),
        )
        self._card(
            cards, 1, "Limpieza",
            "Limpia aplicaciones KDE seleccionadas mediante el script independiente.",
            lambda: self.run_terminal(ROOT / "cleanup" / "cleanup-debian-trixie.sh"),
        )
        self._card(
            cards, 2, "NVIDIA",
            PROJECTS["nvidia"]["description"],
            lambda: self.external("nvidia"),
        )
        self._card(
            cards, 3, "ASUS ROG",
            PROJECTS["asus"]["description"],
            lambda: self.external("asus"),
        )

        actions = ttk.Frame(self)
        actions.pack(fill="x", pady=(0, 10))
        ttk.Button(actions, text="Actualizar componentes externos",
                   command=self.update_all).pack(side="left")
        ttk.Button(actions, text="Abrir carpeta de componentes",
                   command=self.open_components).pack(side="left", padx=8)
        ttk.Button(actions, text="Cerrar",
                   command=self.destroy).pack(side="right")

        self.status = tk.StringVar(value="Listo.")
        ttk.Label(self, textvariable=self.status).pack(anchor="w", pady=(0, 6))

        self.log = tk.Text(self, height=14, wrap="word", state="disabled",
                           font=("Monospace", 9))
        self.log.pack(fill="both", expand=True)

        self.write(
            "Elige una categoría. Los instaladores se ejecutan en una terminal "
            "real para mantener sus confirmaciones y sudo.
"
        )

    def _card(self, parent, column, title, description, command) -> None:
        frame = ttk.LabelFrame(parent, text=title, padding=12)
        frame.grid(row=0, column=column, sticky="nsew", padx=5)
        parent.columnconfigure(column, weight=1)
        ttk.Label(frame, text=description, wraplength=190,
                  justify="left").pack(fill="x", pady=(0, 10))
        ttk.Button(frame, text="Ejecutar", command=command).pack(anchor="e")

    def write(self, text: str) -> None:
        self.log.configure(state="normal")
        self.log.insert("end", text)
        self.log.see("end")
        self.log.configure(state="disabled")

    def terminal(self) -> str | None:
        for cmd in ("konsole", "x-terminal-emulator", "xfce4-terminal", "gnome-terminal"):
            if shutil.which(cmd):
                return cmd
        return None

    def run_terminal(self, script: Path) -> None:
        if not script.is_file():
            messagebox.showerror("Archivo no encontrado", str(script))
            return
        term = self.terminal()
        if not term:
            messagebox.showerror(
                "Terminal no encontrada",
                "No se encontró Konsole ni otro emulador de terminal compatible."
            )
            return

        command = f"cd {shlex.quote(str(script.parent))} && bash {shlex.quote(script.name)}"
        self.write(f"Ejecutando: {script}
")
        self.status.set(f"Ejecutando {script.name}…")
        try:
            subprocess.Popen([term, "-e", "bash", "-lc", command])
        except Exception as exc:
            messagebox.showerror("No se pudo abrir la terminal", str(exc))
            return
        self.status.set(f"Terminal abierta para {script.name}.")

    def sync_project(self, key: str) -> Path | None:
        p = PROJECTS[key]
        dest = Path(p["dir"])
        COMPONENTS.mkdir(parents=True, exist_ok=True)

        if (dest / ".git").is_dir():
            self.write(f"Actualizando {p['name']}…\n")
            result = subprocess.run(
                ["git", "-C", str(dest), "pull", "--ff-only"],
                text=True, capture_output=True
            )
        else:
            self.write(f"Clonando {p['name']}…\n")
            result = subprocess.run(
                ["git", "clone", p["url"], str(dest)],
                text=True, capture_output=True
            )

        if result.stdout:
            self.write(result.stdout + "\n")
        if result.returncode != 0:
            self.write(result.stderr + "\n")
            messagebox.showerror(
                f"Error — {p['name']}",
                result.stderr.strip() or "Git terminó con código de error."
            )
            return None

        self.write(f"{p['name']} listo.\n")
        return dest

    def external(self, key: str) -> None:
        if not shutil.which("git"):
            messagebox.showerror(
                "Git no está instalado",
                "Instala Git con: sudo apt install git"
            )
            return
        dest = self.sync_project(key)
        if dest:
            self.run_terminal(dest / PROJECTS[key]["script"])

    def update_all(self) -> None:
        if not shutil.which("git"):
            messagebox.showerror("Git no está instalado",
                                 "Instala Git con: sudo apt install git")
            return
        ok = True
        for key in PROJECTS:
            if self.sync_project(key) is None:
                ok = False
        self.status.set(
            "Componentes externos actualizados." if ok
            else "La actualización terminó con errores."
        )

    def open_components(self) -> None:
        COMPONENTS.mkdir(parents=True, exist_ok=True)
        opener = shutil.which("xdg-open")
        if opener:
            subprocess.Popen([opener, str(COMPONENTS)])
        else:
            messagebox.showinfo("Carpeta", str(COMPONENTS))


if __name__ == "__main__":
    TrixieGUI().mainloop()
