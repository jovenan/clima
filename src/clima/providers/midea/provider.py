"""Adapter between the `ClimateProvider` contract and an msmart-ng `AirConditioner`."""

from __future__ import annotations

import logging
from contextlib import contextmanager
from typing import Any, Iterator, Mapping

from msmart.base_device import Device
from msmart.device import AirConditioner as AC
from msmart.device.AC.command import PropertyId
from msmart.discover import Discover

from ...core import (Capabilities, Changes, ClimateProvider, DeviceState, Feature, SetupIO, register)
from ...core.errors import ConfigError, DeviceError
from . import setup
from .mapping import (FAN_SPEEDS, HORIZONTAL_BITS, LOUVER_ANGLES, MODES, VERTICAL_BITS, domain_value,
                      louver_position, swing_mode)

log = logging.getLogger(__name__)

REQUIRED_SETTINGS = ("ip", "port", "device_id", "token", "key")


@register
class MideaProvider(ClimateProvider):
    name = "midea"
    display_name = "Midea / Springer / Carrier (local network, protocol V3)"

    def __init__(self, settings: Mapping[str, Any]) -> None:
        super().__init__(settings)
        missing = [k for k in REQUIRED_SETTINGS if k not in self.settings]
        if missing:
            raise ConfigError(f"incomplete Midea configuration (missing: {', '.join(missing)}). Run 'clima setup'.")
        self._device: AC | None = None

    @classmethod
    async def interactive_setup(cls, io: SetupIO) -> dict[str, Any]:
        return await setup.interactive_setup(io)

    # ------------------------------------------------------------- contract

    async def connect(self) -> None:
        address = (self.settings["ip"], int(self.settings["port"]))
        try:
            device = await self._connect_at(*address)
        except DeviceError:
            # The router may have given the AC a new IP (DHCP): look for it on the network by its id
            found = await _discover(int(self.settings["device_id"]))
            if found is None or (found.ip, found.port) == address:
                raise
            device = await self._connect_at(found.ip, found.port)
            log.info("device moved from %s:%s to %s:%s", *address, found.ip, found.port)
            self.update_settings(ip=found.ip, port=found.port)
        self._device = device

    async def capabilities(self) -> Capabilities:
        return _capabilities_of(self._require_device())

    async def read_state(self) -> DeviceState:
        device = self._require_device()
        with _device_errors():
            await _refresh(device)
        return _state_of(device)

    async def apply(self, changes: Changes) -> None:
        device = self._require_device()
        with _device_errors():
            if _set_attributes(device, changes):
                await device.apply()
            if changes.self_clean is True:
                await device.start_self_clean()
            elif changes.self_clean is False:
                # msmart only exposes start_self_clean(); to stop, turn the same property off
                await device._apply_properties({PropertyId.SELF_CLEAN: False})

    async def _connect_at(self, ip: str, port: int) -> AC:
        with _device_errors():
            device = AC(ip=ip, port=port, device_id=int(self.settings["device_id"]))
            await device.authenticate(self.settings["token"], self.settings["key"])
            await device.get_capabilities()
            await _refresh(device)
        return device

    def _require_device(self) -> AC:
        if self._device is None:
            raise DeviceError("not connected")
        return self._device


# ------------------------------------------------------------------ pure translation functions

def _capabilities_of(device: AC) -> Capabilities:
    # Sensors are always declared: the outdoor unit sometimes does not report (e.g. unit off);
    # in that case the value is None and the interfaces hide the reading.
    features = {Feature.POWER, Feature.MODE, Feature.TARGET_TEMPERATURE, Feature.FAN_SPEED,
                Feature.INDOOR_TEMPERATURE, Feature.OUTDOOR_TEMPERATURE}
    optional = {
        Feature.SWING_VERTICAL: AC.SwingMode.VERTICAL in device.supported_swing_modes,
        Feature.SWING_HORIZONTAL: AC.SwingMode.HORIZONTAL in device.supported_swing_modes,
        Feature.LOUVER_VERTICAL: device.supports_vertical_swing_angle,
        Feature.LOUVER_HORIZONTAL: device.supports_horizontal_swing_angle,
        Feature.ECO: device.supports_eco,
        Feature.TURBO: device.supports_turbo,
        Feature.SELF_CLEAN: device.supports_self_clean,
    }
    features |= {feature for feature, supported in optional.items() if supported}
    return Capabilities(
        features=frozenset(features),
        modes=tuple(m for m, v in MODES.items() if v in device.supported_operation_modes),
        fan_speeds=tuple(s for s, v in FAN_SPEEDS.items() if v in device.supported_fan_speeds),
        min_temperature=float(device.min_target_temperature),
        max_temperature=float(device.max_target_temperature),
        temperature_step=0.5,
        louver_positions=len(LOUVER_ANGLES),
    )


def _state_of(device: AC) -> DeviceState:
    swing = device.swing_mode.value
    return DeviceState(
        power=bool(device.power_state),
        mode=domain_value(MODES, device.operational_mode),
        target_temperature=device.target_temperature,
        indoor_temperature=device.indoor_temperature,
        outdoor_temperature=device.outdoor_temperature,
        fan_speed=domain_value(FAN_SPEEDS, device.fan_speed),
        swing_vertical=bool(swing & VERTICAL_BITS),
        swing_horizontal=bool(swing & HORIZONTAL_BITS),
        louver_vertical=louver_position(device.vertical_swing_angle),
        louver_horizontal=louver_position(device.horizontal_swing_angle),
        eco=bool(device.eco),
        turbo=bool(device.turbo),
        self_clean=bool(device.self_clean_active),
    )


def _set_attributes(device: AC, changes: Changes) -> bool:
    """Copies the request onto the msmart object. Returns whether there is anything to `apply()`."""
    c = changes
    if c.power is not None:
        device.power_state = c.power
    if c.mode is not None:
        device.operational_mode = MODES[c.mode]
    if c.target_temperature is not None:
        device.target_temperature = c.target_temperature
    if c.fan_speed is not None:
        device.fan_speed = FAN_SPEEDS[c.fan_speed]
    if c.swing_vertical is not None or c.swing_horizontal is not None:
        current = device.swing_mode.value
        device.swing_mode = swing_mode(
            vertical=c.swing_vertical if c.swing_vertical is not None else bool(current & VERTICAL_BITS),
            horizontal=c.swing_horizontal if c.swing_horizontal is not None else bool(current & HORIZONTAL_BITS),
        )
    if c.louver_vertical is not None:
        device.vertical_swing_angle = LOUVER_ANGLES[c.louver_vertical - 1]
    if c.louver_horizontal is not None:
        device.horizontal_swing_angle = LOUVER_ANGLES[c.louver_horizontal - 1]
    if c.eco is not None:
        device.eco = c.eco
    if c.turbo is not None:
        device.turbo = c.turbo
    return any(v is not None for k, v in c.set_fields().items() if k != "self_clean")


async def _discover(device_id: int) -> Device | None:
    """Searches the local network for the device with this id. Never raises: `None` if not found."""
    try:
        devices = await Discover.discover(auto_connect=False)
    except Exception as e:
        log.info("discovery failed: %s", e)
        return None
    return next((d for d in devices if d.id == device_id), None)


async def _refresh(device: AC) -> None:
    await device.refresh()
    if not device.online:
        raise DeviceError("the device did not respond")


@contextmanager
def _device_errors() -> Iterator[None]:
    """Converts any msmart failure (network, protocol, authentication) into `DeviceError`."""
    try:
        yield
    except DeviceError:
        raise
    except Exception as e:
        raise DeviceError(f"{type(e).__name__}: {e}" if str(e) else type(e).__name__) from e
