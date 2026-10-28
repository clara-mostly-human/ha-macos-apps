"""Start the Spider Farmer Bridge server and announce it to Home Assistant.

Runs with the app's own Python. The app brings its integration: it installs
custom_components/sf (from the same pinned commit as the server) into Home
Assistant's config, and restarts Core when that changed so Home Assistant
loads it. The server listens for the controllers on 8883 (or the port mapped
in the app's network settings) and serves the integration on a WebSocket
bound to localhost; once that answers, an "sf" discovery message lets Home
Assistant offer the integration.
"""

import hashlib
import json
import os
from pathlib import Path
import shutil
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
HA_CONFIG = os.environ.get("APP_HOMEASSISTANT_CONFIG")
# Written into the installed integration, so the app only ever replaces a copy
# it installed itself (never one from HACS or a hand install).
MARKER = ".installed_by_app"


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


def _digest(folder: Path) -> str:
    sha = hashlib.sha256()
    for path in sorted(folder.rglob("*")):
        if path.is_file() and "__pycache__" not in path.parts and path.name != MARKER:
            sha.update(str(path.relative_to(folder)).encode())
            sha.update(path.read_bytes())
    return sha.hexdigest()


def install_integration() -> bool:
    """Put this app's integration into Home Assistant; True when it changed."""
    if not HA_CONFIG:
        log("no Home Assistant config folder mapped; integration not installed")
        return False
    source = SOURCE / "custom_components" / "sf"
    target = Path(HA_CONFIG) / "custom_components" / "sf"
    if target.is_symlink() or (target.exists() and not (target / MARKER).exists()):
        log(f"{target} was not installed by this app; leaving it alone")
        return False
    if target.exists() and _digest(target) == _digest(source):
        return False
    staging = target.with_name("sf.app-new")
    shutil.rmtree(staging, ignore_errors=True)
    shutil.copytree(source, staging, ignore=shutil.ignore_patterns("__pycache__"))
    (staging / MARKER).write_text("core_spider_farmer_bridge\n")
    target.parent.mkdir(parents=True, exist_ok=True)
    old = target.with_name("sf.app-old")
    shutil.rmtree(old, ignore_errors=True)
    if target.exists():
        target.rename(old)
    staging.rename(target)
    shutil.rmtree(old, ignore_errors=True)
    version = json.loads((target / "manifest.json").read_text())["version"]
    log(f"installed the Spider Farmer Bridge integration {version} into {target}")
    return True


def supervisor(method: str, path: str, body: dict | None = None) -> int:
    request = urllib.request.Request(
        f"http://{os.environ['SUPERVISOR']}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={
            "Authorization": f"Bearer {os.environ['SUPERVISOR_TOKEN']}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.status


def announce() -> None:
    """Send the discovery message the Spider Farmer Bridge integration expects."""
    try:
        status = supervisor("POST", "/discovery", {
            "service": "sf", "config": {"host": "127.0.0.1", "port": API_PORT}})
        log(f"discovery sent: {status}")
    except OSError as err:
        log(f"discovery failed: {err}")


def restart_core() -> None:
    """Make Home Assistant load the integration that was just installed."""
    try:
        log(f"restarting Home Assistant to load the integration: {supervisor('POST', '/core/restart')}")
    except OSError as err:
        log(f"restart Home Assistant to load the integration (restart failed: {err})")


def main() -> int:
    opts = options()
    try:
        changed = install_integration()
    except OSError as err:
        log(f"installing the integration failed: {err}")
        changed = False
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
    if changed:
        restart_core()
    return server.wait()


if __name__ == "__main__":
    sys.exit(main())
