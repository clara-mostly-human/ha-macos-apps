"""Run the zigbee-ble bridge on the configured dongle.

One process owns the dongle: Zigbee (EZSP, as an ASH NCP) on the 6638 port for
ZHA, and the chip's Bluetooth controller as raw HCI on the 14433 port for the
nimbled app. Turning the HCI port off in the app's network settings leaves
Zigbee only. Both listen on 127.0.0.1.
"""

import json
import os
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parents[1]
BRIDGE = HERE / "out" / "host" / "ash_bridge.py"
DATA = Path(os.environ["APP_DATA"])


def main() -> int:
    opts = json.loads((DATA / "options.json").read_text())
    device = opts.get("device")
    if not device:
        print("no radio device configured (option: device)", file=sys.stderr)
        return 1
    zigbee = os.environ.get("PORT_6638_TCP")
    if not zigbee:
        print("the Zigbee port (6638/tcp) can't be turned off", file=sys.stderr)
        return 1
    args = [sys.executable, str(BRIDGE), device, "--baud", str(opts.get("baudrate", 460800)),
            "--port", zigbee]
    hci = os.environ.get("PORT_14433_TCP")
    args += ["--hci-tcp", hci] if hci else ["--no-bluetooth"]
    commit = (HERE / "out" / "COMMIT").read_text().strip()
    print(f"zigbee_ble_bridge app: {commit}, {' '.join(args[2:])}", flush=True)
    os.execv(sys.executable, args)   # the bridge gets the app's signals directly


if __name__ == "__main__":
    sys.exit(main())
