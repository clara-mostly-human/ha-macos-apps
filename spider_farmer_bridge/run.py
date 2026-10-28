"""Start the Spider Farmer Bridge server and announce it to Home Assistant.

Runs with the app's own Python. The server listens for the controllers on
8883 (or the port mapped in the app's network settings) and serves the
integration on a WebSocket bound to localhost; once that answers, an "sf"
discovery message lets Home Assistant offer the integration.
"""

import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
import urllib.request

DATA = Path(os.environ["APP_DATA"])
DEVICE_PORT = int(os.environ.get("PORT_8883_TCP") or 8883)
API_PORT = int(os.environ.get("PORT_8484_TCP") or 8484)
SOURCE = Path(__file__).resolve().parent.parent / "out" / "src"


def log(message: str) -> None:
    print(f"[spider_farmer_bridge app] {message}", flush=True)


def options() -> dict:
    return json.loads((DATA / "options.json").read_text())


def wait_for_port(timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", API_PORT), timeout=1):
                return True
        except OSError:
            time.sleep(1)
    return False


def announce() -> None:
    """Send the discovery message the Spider Farmer Bridge integration expects."""
    body = json.dumps(
        {"service": "sf", "config": {"host": "127.0.0.1", "port": API_PORT}}
    ).encode()
    request = urllib.request.Request(
        f"http://{os.environ['SUPERVISOR']}/discovery",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {os.environ['SUPERVISOR_TOKEN']}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            log(f"discovery sent: {response.status}")
    except OSError as err:
        log(f"discovery failed: {err}")


def main() -> int:
    opts = options()
    args = [
        sys.executable, "-m", "bridge.server",
        "--data", str(DATA),
        "--device-port", str(DEVICE_PORT),
        "--api-host", "127.0.0.1",
        "--api-port", str(API_PORT),
        "--log-level", opts.get("log_level", "info"),
    ]
    log(f"starting: {' '.join(args)}")
    server = subprocess.Popen(args, cwd=SOURCE)
    signal.signal(signal.SIGTERM, lambda *_: server.terminate())
    signal.signal(signal.SIGINT, lambda *_: server.terminate())

    if wait_for_port(60):
        announce()
    else:
        log(f"port {API_PORT} did not open within 60 s")
    return server.wait()


if __name__ == "__main__":
    sys.exit(main())
