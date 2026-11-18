# Home Assistant apps for macOS

Apps for the native macOS Supervisor (`macos_support` branch of the
Supervisor). Each app is a normal app folder (`config.yaml` with no image)
plus a `native.yaml` recipe; on macOS only apps with a recipe are available. The
native Supervisor uses this repository as its built-in one, so apps get the
official slugs (`core_matter_server`) Core's integrations expect. A recipe says what to install or build and which script to run.

| App | What |
|---|---|
| `matter_server` | python-matter-server, the Matter controller Home Assistant talks to; its dashboard opens through ingress ("Open Web UI", or the sidebar) |
| `openthread_border_router` | otbr-agent built from a pinned ot-br-posix commit; runs as root through the Supervisor's root helper |
| `nimbled` | Bluetooth for Home Assistant from a radio dongle's Bluetooth controller, with nobody logged in: a NimBLE host daemon built from a pinned [ha-macos-bluetooth](https://github.com/clara-mostly-human/ha-macos-bluetooth) commit; the nimbled integration sets itself up from its discovery |

The run script gets the app environment from the Supervisor: `APP_DATA`
(the app's data folder with `options.json`), `SUPERVISOR` and
`SUPERVISOR_TOKEN` (for discovery), and `PORT_<port>_<proto>` for each port the
user mapped in the app's network settings.
