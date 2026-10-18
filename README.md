# Home Assistant apps for macOS

Apps for the native macOS Supervisor (`macos_support` branch of the
Supervisor). Each app is a normal app folder (`config.yaml`, with
`arch: [macos-aarch64]` and no image) plus a `native.yaml` recipe that says
what to install into the app's Python environment and which script to run.

| App | What |
|---|---|
| `matter_server` | python-matter-server, the Matter controller Home Assistant talks to |

The run script gets the app environment from the Supervisor: `APP_DATA`
(the app's data folder with `options.json`), `SUPERVISOR` and
`SUPERVISOR_TOKEN` (for discovery), and `PORT_<port>_<proto>` for each port the
user mapped in the app's network settings.
