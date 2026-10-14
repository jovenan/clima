"""Domain models, vendor-independent.

- `Feature`: each capability a provider may (or may not) offer.
- `Capabilities`: what a specific device supports. The widget and the CLI use
  it to show only the controls that make sense.
- `DeviceState`: the current reading from the device.
- `Changes`: a change request (only the fields that are set are changed).
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, fields, replace
from enum import Enum
from typing import Any, Iterable, Mapping

from .errors import InvalidRequest


class Feature(str, Enum):
    POWER = "power"
    TARGET_TEMPERATURE = "target_temperature"
    MODE = "mode"
    FAN_SPEED = "fan_speed"
    SWING_VERTICAL = "swing_vertical"
    SWING_HORIZONTAL = "swing_horizontal"
    LOUVER_VERTICAL = "louver_vertical"
    LOUVER_HORIZONTAL = "louver_horizontal"
    ECO = "eco"
    TURBO = "turbo"
    SELF_CLEAN = "self_clean"
    INDOOR_TEMPERATURE = "indoor_temperature"
    OUTDOOR_TEMPERATURE = "outdoor_temperature"


class Mode(str, Enum):
    AUTO = "auto"
    COOL = "cool"
    DRY = "dry"
    HEAT = "heat"
    FAN = "fan"

    @property
    def uses_target_temperature(self) -> bool:
        """Fan mode does not use a target temperature."""
        return self is not Mode.FAN


class FanSpeed(str, Enum):
    AUTO = "auto"
    SILENT = "silent"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    MAX = "max"


@dataclass(frozen=True)
class Capabilities:
    features: frozenset[Feature]
    modes: tuple[Mode, ...] = ()
    fan_speeds: tuple[FanSpeed, ...] = ()
    min_temperature: float = 16.0
    max_temperature: float = 30.0
    temperature_step: float = 0.5
    louver_positions: int = 5

    def supports(self, feature: Feature) -> bool:
        return feature in self.features

    def without(self, disabled: Iterable[Feature]) -> Capabilities:
        """Removes features the user disabled in the configuration."""
        disabled = frozenset(disabled)
        return replace(self, features=self.features - disabled)

    def to_dict(self) -> dict[str, Any]:
        return {
            "features": sorted(f.value for f in self.features),
            "modes": [m.value for m in self.modes],
            "fan_speeds": [s.value for s in self.fan_speeds],
            "min_temperature": self.min_temperature,
            "max_temperature": self.max_temperature,
            "temperature_step": self.temperature_step,
            "louver_positions": self.louver_positions,
        }


@dataclass
class DeviceState:
    power: bool = False
    mode: Mode | None = None
    target_temperature: float | None = None
    indoor_temperature: float | None = None
    outdoor_temperature: float | None = None
    fan_speed: FanSpeed | None = None
    swing_vertical: bool = False
    swing_horizontal: bool = False
    louver_vertical: int | None = None  # fixed position (1..N) or None
    louver_horizontal: int | None = None
    eco: bool = False
    turbo: bool = False
    self_clean: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {k: (v.value if isinstance(v, Enum) else v) for k, v in asdict(self).items()}


# `Changes` field -> feature required to use it
FIELD_FEATURES: dict[str, Feature] = {
    "power": Feature.POWER,
    "mode": Feature.MODE,
    "target_temperature": Feature.TARGET_TEMPERATURE,
    "fan_speed": Feature.FAN_SPEED,
    "swing_vertical": Feature.SWING_VERTICAL,
    "swing_horizontal": Feature.SWING_HORIZONTAL,
    "louver_vertical": Feature.LOUVER_VERTICAL,
    "louver_horizontal": Feature.LOUVER_HORIZONTAL,
    "eco": Feature.ECO,
    "turbo": Feature.TURBO,
    "self_clean": Feature.SELF_CLEAN,
}


@dataclass(frozen=True)
class Changes:
    """Change request. `None` means "leave unchanged"."""

    power: bool | None = None
    mode: Mode | None = None
    target_temperature: float | None = None
    fan_speed: FanSpeed | None = None
    swing_vertical: bool | None = None
    swing_horizontal: bool | None = None
    louver_vertical: int | None = None
    louver_horizontal: int | None = None
    eco: bool | None = None
    turbo: bool | None = None
    self_clean: bool | None = None

    def set_fields(self) -> dict[str, Any]:
        """Only the fields this request changes."""
        return {f.name: getattr(self, f.name) for f in fields(self) if getattr(self, f.name) is not None}

    def is_empty(self) -> bool:
        return not self.set_fields()

    def merged(self, other: Changes) -> Changes:
        """Combines two requests; fields from `other` take precedence."""
        return replace(self, **other.set_fields())

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> Changes:
        """Builds from JSON, checking names and types (does not check capabilities)."""
        if not isinstance(data, Mapping):
            raise InvalidRequest("'changes' must be an object")
        unknown = set(data) - set(FIELD_FEATURES)
        if unknown:
            raise InvalidRequest(f"unknown fields: {', '.join(sorted(unknown))}")
        return cls(**{name: _parse_field(name, value) for name, value in data.items()})


_BOOL_FIELDS = {"power", "swing_vertical", "swing_horizontal", "eco", "turbo", "self_clean"}
_INT_FIELDS = {"louver_vertical", "louver_horizontal"}


def _parse_field(name: str, value: Any) -> Any:
    if name in _BOOL_FIELDS:
        if not isinstance(value, bool):
            raise InvalidRequest(f"{name}: expected true/false, got {value!r}")
        return value
    if name in _INT_FIELDS:
        if isinstance(value, bool) or not isinstance(value, int):
            raise InvalidRequest(f"{name}: expected an integer, got {value!r}")
        return value
    if name == "target_temperature":
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise InvalidRequest(f"{name}: expected a number, got {value!r}")
        return float(value)
    if name == "mode":
        return _parse_enum(Mode, value, "mode")
    if name == "fan_speed":
        return _parse_enum(FanSpeed, value, "fan speed")
    raise InvalidRequest(f"unknown field: {name}")  # pragma: no cover (filtered earlier)


def _parse_enum(enum: type[Enum], value: Any, label: str) -> Enum:
    if isinstance(value, enum):
        return value
    try:
        return enum(value)
    except (ValueError, TypeError):
        options = "|".join(e.value for e in enum)
        raise InvalidRequest(f"unknown {label}: {value!r} (use {options})") from None
