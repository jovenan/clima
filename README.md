**English** · [Português](README.pt-BR.md)

# Clima

Control your air conditioner **over the local network**, without depending on the manufacturer's app. Use it from the terminal (`clima`) or from a panel in the macOS menu bar.

<p align="center">
  <img src="docs/images/panel-full.png" width="300" alt="Full panel">
  &nbsp;&nbsp;
  <img src="docs/images/panel-minimal-provider.png" width="300" alt="Panel for a provider with fewer features">
</p>

- **Multiple manufacturers (providers).** It ships with **Midea** (Midea, Springer Midea, Carrier, Comfee...) and **demo**, a simulated device. To plug in a new manufacturer you implement one interface; nothing else changes.
- **The panel adapts to the device.** Each control appears only if the provider declares that feature. Above, left: a full-featured device; right: a provider that only has mode and temperature.
- **Features can be turned off.** Any feature can be hidden through the configuration (`disabled_features`).
- **100% local** after the initial setup.

## Installation

Requirements: **macOS 14+**, **Python 3.10+** (`brew install python`) and the **Command Line Tools** (`xcode-select --install`) to build the widget.

```sh
git clone https://github.com/jovenan/clima.git
cd clima
./install.sh
clima setup
```

`install.sh` does four things:

1. creates an isolated Python environment in `~/.local/share/clima`;
2. creates the `clima` command in `~/.local/bin`;
3. builds the app and installs `Clima.app` into `~/Applications`;
4. opens the widget and sets it to start at login.

`clima setup` finds the device on the network and asks for the e-mail and password of the manufacturer's app. They are used **only once**, to fetch the device key, and the password is not stored.

No device? Try the simulator (listed as *Simulator (no device)*):

```sh
clima setup --provider demo
```

Installer options:

| Command | What it does |
|---|---|
| `./install.sh --no-app` | only the `clima` command, no widget |
| `./install.sh --no-login` | doesn't open the widget automatically at login |
| `./install.sh --extras ""` | doesn't install provider dependencies (e.g. demo only) |
| `./uninstall.sh` | removes everything but keeps the configuration (`--purge` deletes it too) |

> If you see `⚠ Add to your shell: export PATH=...`, add `export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc`.

## Terminal usage

```sh
clima                         # current state
clima on cool 23 fan auto     # turn on in cool mode, 23°C, automatic fan
clima off
clima 22.5                    # temperature only
clima vertical 2              # up/down louver at position 2
clima horizontal swing        # left/right louver swinging
clima eco on
clima clean on                # self-clean
clima --json                  # state + capabilities as JSON (good for scripts)
clima providers               # available providers
clima help                    # all commands
```

`clima status` shows only the lines the device supports, e.g. `Power`, `Mode`, `Target`, `Indoor`, `Outdoor`, `Fan`, `Airflow`, `Eco`, `Turbo` and `Self-clean`.

Words can be combined in any order, and the ones on the right take precedence. Two rules to remember:
- **Choosing a mode turns the AC on**, unless the command includes `off`.
- **`fan` has two meanings:** on its own it is the Fan mode; followed by a speed (`fan low`) it only changes the fan speed.

## Menu bar widget

The icon shows the mode and the target temperature (e.g. `❄ 23°`). Clicking it opens the panel:

- **Power and temperature.** Use `−`/`+` or the ↑/↓ arrow keys; rapid clicks become a single command.
- **Mode** and **Fan**.
- **Airflow:** air direction on two axes, each with a live drawing of the device and the air stream:
  - **Up/down**: positions 1–5, from *forward* to *floor*;
  - **Left/right**: positions 1–5, from *left* to *right*;
  - the **Swing** button makes that axis oscillate.
- **Eco**, **Turbo** and **Self-clean**. Self-clean needs two taps to start.
- **Refresh (`⌘R`)** and **Quit (`⌘Q`)** in the footer.

The panel reacts immediately and confirms with the device in the background. If a command fails, it goes back to the real state and shows the error in a banner with a **Retry** button.

```sh
# reopen after "Quit"
launchctl kickstart "gui/$(id -u)/dev.clima.app"
# logs
tail -f ~/Library/Logs/clima.log
```

## Configuration

It lives in `~/.config/clima/config.json`. Set `CLIMA_CONFIG` to use a different path.

```json
{
  "provider": "midea",
  "settings": { "ip": "192.168.1.50", "port": 6444, "device_id": 123456789, "token": "…", "key": "…" },
  "disabled_features": ["turbo"]
}
```

`disabled_features` hides features in the widget and the CLI. Accepted values: `power`, `target_temperature`, `mode`, `fan_speed`, `swing_vertical`, `swing_horizontal`, `louver_vertical`, `louver_horizontal`, `eco`, `turbo`, `self_clean`, `indoor_temperature` and `outdoor_temperature`.

The demo provider accepts `settings.features` and `settings.modes` to simulate simpler devices:

```json
{ "provider": "demo", "settings": { "features": ["power", "mode", "target_temperature"], "modes": ["cool", "heat"] } }
```

## Adding a manufacturer

Implement `ClimateProvider` (four required methods), declare what the device supports in `capabilities()` and register the class. The full guide, with an example, is in **[docs/PROVIDERS.md](docs/PROVIDERS.md)**. A provider can also live in a separate package and be discovered through an *entry point*, without touching this repository.

## Development

```sh
make dev          # .venv with the package in editable mode
make app          # rebuild Clima.app
```

To try changes without a device, use the demo provider: `CLIMA_CONFIG=/tmp/demo.json` with `{"provider": "demo"}`.

```
clima/
├── src/clima/
│   ├── core/          # manufacturer-agnostic domain: models, contract, validation, registry, service
│   ├── providers/     # adapters: demo.py, midea/
│   ├── cli/           # parser (pure), formatting, terminal, main
│   ├── bridge/        # line-delimited JSON protocol used by the widget
│   └── factory.py     # builds the service from the configuration
├── app/               # SwiftUI widget (SwiftPM package)
│   ├── Sources/ClimaKit/   # Model, Backend, Store, Views (one section per file)
│   └── Sources/Clima/      # the app
├── docs/              # ARCHITECTURE, PROVIDERS (English and pt-BR)
└── install.sh / uninstall.sh / Makefile
```

The architecture and the design patterns used are described in **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| "the device did not respond" | The IP may have changed. Run `clima setup` again and reserve the device's IP on your router. |
| "'clima setup' requires an interactive terminal" | Run it in Terminal/iTerm, not from scripts or the `!` prefix of other tools. |
| Fan "set by the device" | Some devices (Midea in Dry mode, for example) control the fan on their own. |
| First command after being idle takes ~3 s | The device closes idle connections; reconnection is automatic. |
| Widget doesn't show up (Mac with a notch) | The icon may be hidden behind the notch. Run `defaults write dev.clima.app "NSStatusItem Preferred Position Item-0" -float 250` and reopen the widget, or free up space in the menu bar. To move it later, ⌘-drag the icon. |
| Widget doesn't open | Check `~/Library/Logs/clima.log` and make sure "Clima" is allowed in System Settings → General → Login Items. |

## License

[MIT](LICENSE) © 2026 Jonatas Venancio.
