# Home Assistant apps for macOS

Apps for the native macOS Supervisor (`macos_support` branch of the
Supervisor). Each app is a normal app folder (`config.yaml` with no image)
plus a `native.yaml` recipe; on macOS only apps with a recipe are available. The
native Supervisor uses this repository as its built-in one, so apps get the
official slugs (`core_matter_server`) Core's integrations expect. A says what to install into the app's Python environment and which script to run.

| App | What |
|---|---|
| `matter_server` | python-matter-server, the Matter controller Home Assistant talks to |
| `openthread_border_router` | otbr-agent built from a pinned ot-br-posix commit; runs as root through the Supervisor's root helper |
| `spider_farmer_bridge` | Spider Farmer GGS grow controllers: the bridge server from a pinned spider_farmer_bridge commit; the Spider Farmer Bridge integration connects to it |

The run script gets the app environment from the Supervisor: `APP_DATA`
(the app's data folder with `options.json`), `SUPERVISOR` and
`SUPERVISOR_TOKEN` (for discovery), and `PORT_<port>_<proto>` for each port the
user mapped in the app's network settings.
