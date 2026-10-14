"""`clima setup` for the Midea provider: finds the device on the network and gets its token/key from the cloud.

The password is used only here, once, and is not saved. After that everything runs on the local network.
"""

from __future__ import annotations

from typing import Any

from msmart.base_device import Device
from msmart.cloud import CloudError, NetHomePlusCloud, SmartHomeCloud
from msmart.const import DeviceType
from msmart.discover import Discover
from msmart.lan import Security

from ...core import SetupIO
from ...core.errors import DeviceError

CLOUDS = (SmartHomeCloud, NetHomePlusCloud)


async def interactive_setup(io: SetupIO) -> dict[str, Any]:
    host = io.ask("Air conditioner IP (Enter to search the network)", default="")
    device = await _find_device(io, host or None)
    io.info(f"Found: {device.name} at {device.ip} (id {device.id})")

    account = io.ask("Email for the app account (SmartHome / NetHome Plus)")
    password = io.ask_secret("Password")
    token, key = await _fetch_token(io, device, account, password)

    return {"ip": device.ip, "port": device.port, "device_id": device.id, "token": token, "key": key}


async def _find_device(io: SetupIO, host: str | None) -> Device:
    if host:
        found = await Discover.discover_single(host, auto_connect=False)
        devices = [found] if found else []
    else:
        io.info("Searching for devices on the network...")
        devices = await Discover.discover(auto_connect=False)
    devices = [d for d in devices if d.type == DeviceType.AIR_CONDITIONER]

    if not devices:
        raise DeviceError(f"no Midea air conditioner responded{' at ' + host if host else ' on the network'}")
    if len(devices) == 1:
        return devices[0]
    for i, d in enumerate(devices, 1):
        io.info(f"  {i}. {d.name} ({d.ip})")
    choice = io.ask("Which one?", default="1")
    try:
        return devices[int(choice) - 1]
    except (ValueError, IndexError):
        raise DeviceError(f"invalid choice: {choice}") from None


async def _fetch_token(io: SetupIO, device: Device, account: str, password: str) -> tuple[str, str]:
    """Tries both Midea clouds and both id formats until the device accepts the token."""
    for cloud_class in CLOUDS:
        cloud = cloud_class(account=account, password=password)
        try:
            await cloud.login()
        except CloudError as e:
            io.info(f"  {cloud_class.__name__}: login failed ({e})")
            continue

        for endian in ("little", "big"):
            udpid = Security.udpid(device.id.to_bytes(6, endian)).hex()
            try:
                token, key = await cloud.get_token(udpid, device.id)
                await device.authenticate(token, key)
                return token, key
            except Exception as e:
                io.info(f"  {cloud_class.__name__} ({endian}): {e}")

    raise DeviceError("could not get token/key with this account")
