"""Validation of requests against the device's capabilities.

Runs *before* any command reaches the provider: an invalid request is never
half-applied.
"""

from __future__ import annotations

from dataclasses import replace

from .errors import InvalidRequest, UnsupportedFeature
from .models import FIELD_FEATURES, Capabilities, Changes, Feature


def validate(changes: Changes, capabilities: Capabilities) -> Changes:
    """Checks the request and returns the normalized version (ready for the provider)."""
    if changes.is_empty():
        raise InvalidRequest("no changes given")

    changes = _normalize(changes, capabilities)
    _check_features(changes, capabilities)
    _check_mode(changes, capabilities)
    _check_fan_speed(changes, capabilities)
    _check_temperature(changes, capabilities)
    _check_louver("louver_vertical", changes.louver_vertical, capabilities)
    _check_louver("louver_horizontal", changes.louver_horizontal, capabilities)
    return changes


def _normalize(changes: Changes, capabilities: Capabilities) -> Changes:
    """Fixing an axis's louver stops that axis from swinging (when the device can swing)."""
    if (changes.louver_vertical is not None and changes.swing_vertical is None
            and capabilities.supports(Feature.SWING_VERTICAL)):
        changes = replace(changes, swing_vertical=False)
    if (changes.louver_horizontal is not None and changes.swing_horizontal is None
            and capabilities.supports(Feature.SWING_HORIZONTAL)):
        changes = replace(changes, swing_horizontal=False)
    return changes


def _check_features(changes: Changes, capabilities: Capabilities) -> None:
    for name in changes.set_fields():
        feature = FIELD_FEATURES[name]
        if not capabilities.supports(feature):
            raise UnsupportedFeature(f"the device does not offer '{feature.value}'")


def _check_mode(changes: Changes, capabilities: Capabilities) -> None:
    if changes.mode is not None and changes.mode not in capabilities.modes:
        raise UnsupportedFeature(f"the device does not support mode {changes.mode.value}")


def _check_fan_speed(changes: Changes, capabilities: Capabilities) -> None:
    if changes.fan_speed is not None and changes.fan_speed not in capabilities.fan_speeds:
        raise UnsupportedFeature(f"the device does not support fan speed {changes.fan_speed.value}")


def _check_temperature(changes: Changes, capabilities: Capabilities) -> None:
    value = changes.target_temperature
    if value is None:
        return
    low, high, step = capabilities.min_temperature, capabilities.max_temperature, capabilities.temperature_step
    if not low <= value <= high:
        raise InvalidRequest(f"temperature must be between {low:g} and {high:g}")
    steps = (value - low) / step
    if abs(steps - round(steps)) > 1e-6:
        raise InvalidRequest(f"temperature must change in steps of {step:g} degree")


def _check_louver(name: str, value: int | None, capabilities: Capabilities) -> None:
    if value is not None and not 1 <= value <= capabilities.louver_positions:
        raise InvalidRequest(f"{name}: position must be from 1 to {capabilities.louver_positions}")
