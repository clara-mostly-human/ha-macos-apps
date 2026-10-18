"""Start python-matter-server and announce it to Home Assistant.

Runs with the app's own Python. Mirrors the official Matter Server app:
storage in the app's data folder, options from options.json, and a
"matter" discovery message once the WebSocket port answers.
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
PORT = int(os.environ.get("PORT_5580_TCP") or 5580)
SERVER = Path(sys.executable).parent / "matter-server"


def log(message: str) -> None:
    print(f"[matter_server app] {message}", flush=True)


def options() -> dict:
    return json.loads((DATA / "options.json").read_text())


def wait_for_port(timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", PORT), timeout=1):
                return True
        except OSError:
            time.sleep(1)
    return False


def announce() -> None:
    """Send the discovery message Home Assistant's Matter integration expects."""
    body = json.dumps(
        {"service": "matter", "config": {"host": "127.0.0.1", "port": PORT}}
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
        str(SERVER),
        "--storage-path", str(DATA),
        "--port", str(PORT),
        "--log-level", opts.get("log_level", "info"),
        "--log-level-sdk", opts.get("log_level_sdk", "error"),
    ]
    if opts.get("enable_test_net_dcl"):
        args.append("--enable-test-net-dcl")
    args += opts.get("extra_args", [])

    log(f"starting: {' '.join(args)}")
    server = subprocess.Popen(args)
    signal.signal(signal.SIGTERM, lambda *_: server.terminate())
    signal.signal(signal.SIGINT, lambda *_: server.terminate())

    if wait_for_port(120):
        announce()
    else:
        log(f"port {PORT} did not open within 120 s")
    return server.wait()


if __name__ == "__main__":
    sys.exit(main())
