**English** · [Português](PROVIDERS.pt-BR.md)

# How to add a provider (manufacturer)

A *provider* is the **adapter** between Clima and a manufacturer's API. The CLI, the bridge and the widget only know the `ClimateProvider` contract. A new provider works in all of them without changing any other line.

For a small, complete implementation, read **`src/clima/providers/demo.py`**. For a real one, read **`src/clima/providers/midea/`**.

## 1. Implement the contract

```python
# src/clima/providers/mybrand.py
from typing import Any, Mapping

from ..core import (Capabilities, Changes, ClimateProvider, DeviceError, DeviceState, FanSpeed, Feature,
                    Mode, SetupIO, register)
from ..core.errors import ConfigError

from mybrand_sdk import Client, SdkError  # the manufacturer's library


@register
class MyBrandProvider(ClimateProvider):
    name = "mybrand"                             # used as "provider" in the config and in --provider
    display_name = "My Brand (Wi-Fi)"           # shown by `clima providers`

    def __init__(self, settings: Mapping[str, Any]) -> None:
        super().__init__(settings)
        if "host" not in self.settings:
            raise ConfigError("incomplete configuration. Run 'clima setup'.")
        self._client: Client | None = None

    @classmethod
    async def interactive_setup(cls, io: SetupIO) -> dict[str, Any]:
        """Optional. Whatever is returned here is saved as `settings`."""
        host = io.ask("Device IP")
        return {"host": host}

    async def connect(self) -> None:
        try:
            self._client = await Client.connect(self.settings["host"])
        except SdkError as e:
            raise DeviceError(str(e)) from e

    async def capabilities(self) -> Capabilities:
        # Declare ONLY what the device really does: the widget and the CLI are built from this
        return Capabilities(
            features=frozenset({Feature.POWER, Feature.MODE, Feature.TARGET_TEMPERATURE,
                                Feature.INDOOR_TEMPERATURE, Feature.FAN_SPEED}),
            modes=(Mode.COOL, Mode.HEAT, Mode.FAN),
            fan_speeds=(FanSpeed.AUTO, FanSpeed.LOW, FanSpeed.HIGH),
            min_temperature=17, max_temperature=30, temperature_step=1,
        )

    async def read_state(self) -> DeviceState:
        try:
            raw = await self._client.status()
        except SdkError as e:
            raise DeviceError(str(e)) from e
        return DeviceState(
            power=raw["on"],
            mode={"cooling": Mode.COOL, "heating": Mode.HEAT, "fan": Mode.FAN}.get(raw["mode"]),
            target_temperature=raw["setpoint"],
            indoor_temperature=raw["room"],
            fan_speed={"auto": FanSpeed.AUTO, "1": FanSpeed.LOW, "3": FanSpeed.HIGH}.get(raw["fan"]),
        )

    async def apply(self, changes: Changes) -> None:
        # `changes` was already validated against capabilities(): only supported fields, within range
        payload = {}
        if changes.power is not None:
            payload["on"] = changes.power
        if changes.target_temperature is not None:
            payload["setpoint"] = changes.target_temperature
        # ... other fields
        try:
            await self._client.send(payload)
        except SdkError as e:
            raise DeviceError(str(e)) from e
```

## 2. Contract rules

| Rule | Why |
|---|---|
| **Communication failures become `DeviceError`** (or `OSError`/`TimeoutError`). | `ClimateService` reconnects and retries (3×, with growing delays). |
| **Invalid configuration becomes `ConfigError`.** | It is shown to the user with the hint to run `clima setup`. |
| **Don't validate ranges in `apply()`.** | `ClimateService` validates against `capabilities()` first, so an invalid request never reaches the provider. |
| **`connect()` may be called again** after a failure. | That is how reconnection works. |
| **`capabilities()` is read once per connection.** | Don't rely on momentary readings (e.g. a sensor that sometimes doesn't answer). Declare the sensor and return `None` in the state. |
| **Values the device controls on its own** come back as `None`. | The interfaces show "set by the device". |
| **A louver position is `1..louver_positions`**; `None` = no fixed position. | Fixing a position stops that axis from swinging (the service already sends `swing_*=False` along with it). |

The possible features are in `Feature` (`src/clima/core/models.py`). Each `Changes` field requires one of them (`FIELD_FEATURES`).

## 3. Register it

**Inside this repository:** use the `@register` decorator and add the module to `BUILTIN_PROVIDERS` (`src/clima/core/registry.py`). If the provider needs libraries, declare an *extra* in `pyproject.toml`:

```toml
[project.optional-dependencies]
mybrand = ["mybrand-sdk>=1.0"]
```

If the library is not installed, the provider is listed as unavailable in `clima providers`, with the reason, and the others keep working.

**In a separate package (plugin):** no changes here. Declare the entry point in your package's `pyproject.toml` and install it into the same environment (`~/.local/share/clima/venv/bin/pip install your-package`):

```toml
[project.entry-points."clima.providers"]
mybrand = "my_package.provider:MyBrandProvider"
```

## 4. Use it

```sh
clima setup --provider mybrand
clima                 # should show only the lines you declared
clima on cool 23
```
