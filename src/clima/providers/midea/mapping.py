"""Translation between Clima's model and the msmart-ng library enums."""

from __future__ import annotations

from typing import TypeVar

from msmart.device import AirConditioner as AC

from ...core import FanSpeed, Mode

MODES: dict[Mode, AC.OperationalMode] = {
    Mode.AUTO: AC.OperationalMode.AUTO,
    Mode.COOL: AC.OperationalMode.COOL,
    Mode.DRY: AC.OperationalMode.DRY,
    Mode.HEAT: AC.OperationalMode.HEAT,
    Mode.FAN: AC.OperationalMode.FAN_ONLY,
}

FAN_SPEEDS: dict[FanSpeed, AC.FanSpeed] = {
    FanSpeed.AUTO: AC.FanSpeed.AUTO,
    FanSpeed.SILENT: AC.FanSpeed.SILENT,
    FanSpeed.LOW: AC.FanSpeed.LOW,
    FanSpeed.MEDIUM: AC.FanSpeed.MEDIUM,
    FanSpeed.HIGH: AC.FanSpeed.HIGH,
    FanSpeed.MAX: AC.FanSpeed.MAX,
}

#: Louver position (1..5) -> msmart angle; `SwingAngle.OFF` = no fixed position
LOUVER_ANGLES: list[AC.SwingAngle] = [
    AC.SwingAngle.POS_1, AC.SwingAngle.POS_2, AC.SwingAngle.POS_3, AC.SwingAngle.POS_4, AC.SwingAngle.POS_5,
]

#: msmart's `swing_mode` is a bit field: vertical (up/down) and horizontal (left/right)
VERTICAL_BITS = AC.SwingMode.VERTICAL.value
HORIZONTAL_BITS = AC.SwingMode.HORIZONTAL.value

K = TypeVar("K")


def domain_value(mapping: dict[K, object], device_value: object) -> K | None:
    """Reverse lookup: msmart value -> Clima value (None if not mapped)."""
    return next((k for k, v in mapping.items() if v == device_value), None)


def louver_position(angle: AC.SwingAngle) -> int | None:
    return LOUVER_ANGLES.index(angle) + 1 if angle in LOUVER_ANGLES else None


def swing_mode(vertical: bool, horizontal: bool) -> AC.SwingMode:
    return AC.SwingMode((VERTICAL_BITS if vertical else 0) | (HORIZONTAL_BITS if horizontal else 0))
