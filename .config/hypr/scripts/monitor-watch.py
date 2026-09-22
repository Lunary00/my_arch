#!/usr/bin/env python3
"""Ouve o socket de eventos do Hyprland e reaplica o layout de monitores
sempre que um monitor for conectado/removido ou a config for recarregada.
Chama ~/.config/hypr/scripts/monitores.sh (com debounce)."""

import os
import socket
import subprocess
import threading
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SIG = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
SOCK = os.path.join(RUNTIME, "hypr", SIG, ".socket2.sock")
SCRIPT = os.path.expanduser("~/.config/hypr/scripts/monitores.sh")

EVENTOS = ("monitoradded", "monitorremoved", "configreloaded")

_timer = None
_lock = threading.Lock()


def _aplicar():
    subprocess.run([SCRIPT], check=False)


def _agendar():
    global _timer
    with _lock:
        if _timer is not None:
            _timer.cancel()
        _timer = threading.Timer(1.0, _aplicar)
        _timer.daemon = True
        _timer.start()


def main():
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(SOCK)
                with s.makefile("r") as f:
                    for linha in f:
                        if linha.startswith(EVENTOS):
                            _agendar()
        except Exception:
            time.sleep(2)


if __name__ == "__main__":
    main()
