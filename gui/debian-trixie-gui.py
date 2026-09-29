#!/usr/bin/env python3
"""
Debian Trixie Setup — lanzador gráfico Qt.

La aplicación mantiene un único pseudo-terminal (PTY) durante toda su
ejecución. Así sudo, whiptail y los scripts comparten el mismo terminal,
mientras la contraseña se introduce mediante el campo gráfico de abajo.
"""
from __future__ import annotations

import os
import pty
import shutil
import signal
import subprocess
from pathlib import Path

import pyte
from PyQt6.QtCore import QSocketNotifier, QTimer, Qt
from PyQt6.QtGui import QFont, QKeyEvent
from PyQt6.QtWidgets import (
    QApplication,
    QFrame,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QPushButton,
    QPlainTextEdit,
    QVBoxLayout,
    QWidget,
)


ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = (
    Path.home()
    / ".local"
    / "share"
    / "debian-trixie-setup"
    / "components"
)

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


class EmbeddedTerminal(QPlainTextEdit):
    """Terminal Qt sencilla que envía las teclas al PTY real."""

    def __init__(self, write_input):
        super().__init__()
        self._write_input = write_input
        self.setReadOnly(True)
        self.setUndoRedoEnabled(False)
        self.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)

        font = QFont("DejaVu Sans Mono", 10)
        self.setFont(font)

    def keyPressEvent(self, event: QKeyEvent) -> None:
        key = event.key()
        modifiers = event.modifiers()
        text = event.text()

        sequences = {
            Qt.Key.Key_Return: b"\r",
            Qt.Key.Key_Enter: b"\r",
            Qt.Key.Key_Backspace: b"\x7f",
            Qt.Key.Key_Tab: b"\t",
            Qt.Key.Key_Escape: b"\x1b",
            Qt.Key.Key_Up: b"\x1b[A",
            Qt.Key.Key_Down: b"\x1b[B",
            Qt.Key.Key_Right: b"\x1b[C",
            Qt.Key.Key_Left: b"\x1b[D",
            Qt.Key.Key_Home: b"\x1b[H",
            Qt.Key.Key_End: b"\x1b[F",
            Qt.Key.Key_Delete: b"\x1b[3~",
        }

        if modifiers & Qt.KeyboardModifier.ControlModifier:
            if Qt.Key.Key_A <= key <= Qt.Key.Key_Z:
                self._write_input(bytes([key - Qt.Key.Key_A + 1]))
                return

        sequence = sequences.get(key)
        if sequence is not None:
            self._write_input(sequence)
            return

        if text:
            self._write_input(text.encode("utf-8"))


class TrixieGUI(QMainWindow):
    def __init__(self) -> None:
        super().__init__()

        self.setWindowTitle("Debian Trixie Setup")
        self.resize(1100, 700)
        self.setMinimumSize(820, 560)

        self.master_fd: int | None = None
        self.pid: int | None = None
        self.notifier: QSocketNotifier | None = None

        self.screen = pyte.Screen(120, 40)
        self.stream = pyte.Stream(self.screen)

        self.output_buffer = ""
        self.authenticated = False
        self.auth_pending = False
        self.auth_password = ""
        self.pending_action = None

        self._build()
        self._start_shell()

    def _build(self) -> None:
        root = QWidget()
        self.setCentralWidget(root)

        layout = QVBoxLayout(root)
        layout.setSpacing(10)

        title = QLabel("<h1>Debian Trixie Setup</h1>")
        layout.addWidget(title)

        layout.addWidget(
            QLabel("Debian 13 · KDE Plasma · lanzador de componentes")
        )

        cards = [
            (
                "Sistema Trixie",
                "Repositorios, paquetes base, microcode, zram y Firefox.",
                lambda: self.run_script(
                    ROOT / "setup" / "setup-debian-trixie.sh"
                ),
            ),
            (
                "Limpieza",
                "Limpieza de aplicaciones KDE mediante el script independiente.",
                lambda: self.run_script(
                    ROOT / "cleanup" / "cleanup-debian-trixie.sh"
                ),
            ),
            (
                "Gaming",
                "Steam/Proton, GameMode, MangoHud, Protontricks, Heroic, "
                "Lutris y Gamescope.",
                lambda: self.run_script(
                    ROOT / "gaming" / "setup-gaming-debian-trixie.sh"
                ),
            ),
            (
                "NVIDIA",
                PROJECTS["nvidia"]["description"],
                lambda: self.external("nvidia"),
            ),
            (
                "ASUS ROG",
                PROJECTS["asus"]["description"],
                lambda: self.external("asus"),
            ),
        ]

        cards_layout = QGridLayout()
        for index, (name, description, action) in enumerate(cards):
            frame = QGroupBox(name)
            box = QVBoxLayout(frame)

            label = QLabel(description)
            label.setWordWrap(True)
            box.addWidget(label)

            button = QPushButton("Ejecutar")
            button.clicked.connect(action)
            box.addWidget(button)

            cards_layout.addWidget(frame, index // 5, index % 5)

        layout.addLayout(cards_layout)

        actions = QHBoxLayout()

        update = QPushButton("Actualizar componentes externos")
        update.clicked.connect(self.update_all)
        actions.addWidget(update)

        folder = QPushButton("Abrir carpeta de componentes")
        folder.clicked.connect(self.open_components)
        actions.addWidget(folder)

        clear = QPushButton("Limpiar terminal")
        clear.clicked.connect(self.clear_terminal)
        actions.addWidget(clear)

        actions.addStretch()

        close = QPushButton("Cerrar")
        close.clicked.connect(self.close)
        actions.addWidget(close)

        layout.addLayout(actions)

        auth = QGroupBox("Autenticación sudo")
        auth_layout = QHBoxLayout(auth)

        auth_layout.addWidget(QLabel("Contraseña:"))

        self.password = QLineEdit()
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        self.password.setPlaceholderText("Contraseña de sudo")
        self.password.returnPressed.connect(self.authenticate)
        auth_layout.addWidget(self.password, 1)

        auth_button = QPushButton("Autenticar")
        auth_button.clicked.connect(self.authenticate)
        auth_layout.addWidget(auth_button)

        layout.addWidget(auth)

        self.status = QLabel("Iniciando terminal integrada…")
        layout.addWidget(self.status)

        terminal_frame = QFrame()
        terminal_layout = QVBoxLayout(terminal_frame)
        terminal_layout.setContentsMargins(0, 0, 0, 0)

        self.terminal = EmbeddedTerminal(self._write_pty)
        terminal_layout.addWidget(self.terminal)
        layout.addWidget(terminal_frame, 1)

    def _start_shell(self) -> None:
        pid, fd = pty.fork()

        if pid == 0:
            os.chdir(ROOT)
            os.environ["TERM"] = "xterm-256color"
            os.environ["PS1"] = "__TRIXIE_GUI_PROMPT__ "
            os.execv(
                "/bin/bash",
                ["bash", "--noprofile", "--norc", "-i"],
            )

        self.pid = pid
        self.master_fd = fd
        os.set_blocking(fd, False)

        self.notifier = QSocketNotifier(
            fd,
            QSocketNotifier.Type.Read,
        )
        self.notifier.activated.connect(self._read_pty)

        self._write_pty(
            b"printf '\\nDebian Trixie Setup listo.\\n'\n"
        )

    def _read_pty(self) -> None:
        if self.master_fd is None:
            return

        try:
            data = os.read(self.master_fd, 65536)
        except (BlockingIOError, OSError):
            return

        if not data:
            return

        text = data.decode("utf-8", "replace")
        self.output_buffer = (self.output_buffer + text)[-12000:]

        self.stream.feed(text)
        self._render_terminal()

        if self.auth_pending:
            lowered = self.output_buffer.lower()
            prompts = (
                "password",
                "contraseña",
                "senha",
                "mot de passe",
            )

            if any(prompt in lowered for prompt in prompts):
                password = self.auth_password
                self.auth_password = ""
                self.auth_pending = False
                self._write_pty((password + "\n").encode("utf-8"))
                password = ""

        marker = "__TRIXIE_SUDO_RESULT__:"
        if marker not in self.output_buffer:
            return

        result = (
            self.output_buffer.rsplit(marker, 1)[1]
            .splitlines()[0]
            .strip()
        )

        self.auth_pending = False
        self.auth_password = ""
        self.output_buffer = ""

        if result == "0":
            self.authenticated = True
            self.status.setText("Sudo autenticado. Puedes ejecutar el instalador.")
            action = self.pending_action
            self.pending_action = None

            if action is not None:
                QTimer.singleShot(0, action)
        else:
            self.authenticated = False
            self.pending_action = None
            self.status.setText(
                "Contraseña de sudo incorrecta o sudo rechazó la autenticación."
            )

    def _render_terminal(self) -> None:
        self.terminal.setPlainText("\n".join(self.screen.display))
        cursor = self.terminal.textCursor()
        cursor.movePosition(cursor.MoveOperation.End)
        self.terminal.setTextCursor(cursor)

    def _write_pty(self, data: bytes) -> None:
        if self.master_fd is None:
            return

        try:
            os.write(self.master_fd, data)
        except OSError:
            pass

    def authenticate(self) -> None:
        if self.auth_pending:
            return

        password = self.password.text()
        self.password.clear()

        if not password:
            self.status.setText("Introduce la contraseña de sudo.")
            return

        self.auth_pending = True
        self.auth_password = password
        self.output_buffer = ""
        self.status.setText("Esperando autenticación de sudo…")

        # La autenticación se hace dentro del mismo PTY que usarán
        # posteriormente los scripts. Esto evita el problema de sudo
        # cuando timestamp_type está ligado al terminal.
        self._write_pty(
            b"sudo -S -v; "
            b"printf '\\n__TRIXIE_SUDO_RESULT__:%s\\n' "$?"\n"
        )
        # Normalmente la contraseña se envía al detectar el prompt de sudo.
        # Este temporizador cubre prompts traducidos o respuestas lentas,
        # pero no envía nada si sudo ya terminó.
        QTimer.singleShot(2000, self._send_pending_password)

    def _send_pending_password(self) -> None:
        if not self.auth_pending:
            return

        password = self.auth_password
        self.auth_password = ""
        self.auth_pending = False

        if password:
            self._write_pty((password + "\\n").encode("utf-8"))

    def _ensure_sudo(self, action) -> bool:
        if self.authenticated:
            return True

        self.pending_action = action
        self.password.setFocus()
        self.status.setText(
            "Introduce la contraseña de sudo y pulsa «Autenticar»."
        )
        return False

    def run_script(self, script: Path) -> None:
        if not self._ensure_sudo(lambda: self.run_script(script)):
            return

        if not script.is_file():
            self.status.setText(f"Archivo no encontrado: {script}")
            self._write_pty(
                f"printf '\\n[ERROR] Archivo no encontrado: {script}\\n'\n"
                .encode("utf-8")
            )
            return

        self.status.setText(f"Ejecutando {script.name}…")
        self._write_pty(
            f"bash {str(script)!r}\n".encode("utf-8")
        )

    def external(self, key: str) -> None:
        if not self._ensure_sudo(lambda: self.external(key)):
            return

        if not shutil.which("git"):
            self.status.setText("Git no está instalado.")
            self._write_pty(
                b"printf '\\n[ERROR] Git no está instalado.\\n'\n"
            )
            return

        project = PROJECTS[key]
        destination = Path(project["dir"])
        COMPONENTS.mkdir(parents=True, exist_ok=True)

        if (destination / ".git").is_dir():
            command = (
                f"git -C {str(destination)!r} pull --ff-only && "
                f"bash {str(destination / project['script'])!r}"
            )
        else:
            command = (
                f"git clone {project['url']!r} {str(destination)!r} && "
                f"bash {str(destination / project['script'])!r}"
            )

        self.status.setText(f"Preparando {project['name']}…")
        self._write_pty((command + "\n").encode("utf-8"))

    def update_all(self) -> None:
        if not shutil.which("git"):
            self.status.setText("Git no está instalado.")
            return

        COMPONENTS.mkdir(parents=True, exist_ok=True)
        commands = []

        for project in PROJECTS.values():
            destination = Path(project["dir"])

            if (destination / ".git").is_dir():
                commands.append(
                    f"git -C {str(destination)!r} pull --ff-only"
                )
            else:
                commands.append(
                    f"git clone {project['url']!r} {str(destination)!r}"
                )

        if commands:
            self._write_pty(
                (" && ".join(commands) + "\n").encode("utf-8")
            )

    def open_components(self) -> None:
        COMPONENTS.mkdir(parents=True, exist_ok=True)
        opener = shutil.which("xdg-open")

        if opener:
            subprocess.Popen([opener, str(COMPONENTS)])
        else:
            self.status.setText(
                f"No se encontró xdg-open. Carpeta: {COMPONENTS}"
            )

    def clear_terminal(self) -> None:
        self.screen.reset()
        self._render_terminal()

    def closeEvent(self, event) -> None:
        if self.notifier is not None:
            self.notifier.setEnabled(False)

        if self.master_fd is not None:
            try:
                os.write(self.master_fd, b"exit\n")
                os.close(self.master_fd)
            except OSError:
                pass

        if self.pid is not None:
            try:
                os.kill(self.pid, signal.SIGHUP)
            except OSError:
                pass

        event.accept()


if __name__ == "__main__":
    app = QApplication([])
    window = TrixieGUI()
    window.show()
    app.exec()
