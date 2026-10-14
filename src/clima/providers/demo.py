"""Demo provider: an in-memory simulated air conditioner.

Useful for trying the CLI and the widget without a device, and for seeing how
the interface adapts to capabilities. Example configuration that hides features:

    {"provider": "demo", "settings": {"features": ["power", "mode", "target_temperature"]}}
"""

from __future__ import annotations

from dataclasses import replace
from typing import Any, Mapping

from ..core import Capabilities, Changes, ClimateProvider, DeviceState, FanSpeed, Feature, Mode, register
from ..core.errors import ConfigError


@register
class DemoProvider(ClimateProvider):
    name = "demo"
    display_name = "Simulator (no device)"

    def __init__(self, settings: Mapping[str, Any]) -> None:
        super().__init__(settings)
        self._capabilities = _capabilities_from(self.settings)
        self._state = DeviceState(
            power=False, mode=Mode.COOL, target_temperature=24.0, indoor_temperature=27.0,
            outdoor_temperature=31.0, fan_speed=FanSpeed.AUTO,
        )

    async def connect(self) -> None:
        pass

    async def capabilities(self) -> Capabilities:
        return self._capabilities

    async def read_state(self) -> DeviceState:
        self._simulate_room()
        return replace(self._state)

    async def apply(self, changes: Changes) -> None:
        state = replace(self._state, **changes.set_fields())
        if changes.swing_vertical:
            state.louver_vertical = None
        if changes.swing_horizontal:
            state.louver_horizontal = None
        if changes.self_clean:
            state.power = False  # self-clean runs with the unit off
        if changes.power:
            state.self_clean = False
        self._state = state

    def _simulate_room(self) -> None:
        """The room temperature moves towards the target while the unit is on."""
        s = self._state
        if s.power and s.mode and s.mode.uses_target_temperature and s.target_temperature is not None:
            delta = s.target_temperature - (s.indoor_temperature or s.target_temperature)
            s.indoor_temperature = round((s.indoor_temperature or 0) + max(-0.3, min(0.3, delta)), 1)


def _capabilities_from(settings: Mapping[str, Any]) -> Capabilities:
    try:
        features = frozenset(Feature(f) for f in settings.get("features", [f.value for f in Feature]))
        modes = tuple(Mode(m) for m in settings.get("modes", [m.value for m in Mode]))
    except ValueError as e:
        raise ConfigError(f"demo configuration: {e}") from None
    return Capabilities(features=features | {Feature.POWER}, modes=modes, fan_speeds=tuple(FanSpeed))
