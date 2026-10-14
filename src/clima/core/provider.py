"""Contract every provider (vendor/protocol) implements.

A provider is an *Adapter*: it translates Clima's domain model (`Changes`,
`DeviceState`, `Capabilities`) to a vendor's API. To add a new vendor, just
implement this class and register it (see `docs/PROVIDERS.md`).
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, ClassVar, Mapping, Protocol

from .models import Capabilities, Changes, DeviceState


class SetupIO(Protocol):
    """User interaction during `clima setup` (injected by the CLI)."""

    def ask(self, question: str, default: str | None = None) -> str: ...

    def ask_secret(self, question: str) -> str: ...

    def info(self, message: str) -> None: ...


class ClimateProvider(ABC):
    """Base of all providers.

    Contract rules:
    - `connect()` is called before any other operation and may be called again
      after a failure (`ClimateService` handles reconnecting).
    - Communication failures must become `DeviceError` (or `OSError`/`TimeoutError`).
    - `apply()` only receives requests already validated against `capabilities()`.
    """

    #: Identifier used in the configuration and in `clima setup --provider`.
    name: ClassVar[str]
    #: Friendly name shown to the user.
    display_name: ClassVar[str]

    def __init__(self, settings: Mapping[str, Any]) -> None:
        self.settings = dict(settings)

    @classmethod
    async def interactive_setup(cls, io: SetupIO) -> dict[str, Any]:
        """Asks the user what is needed and returns the `settings` to save in the configuration."""
        return {}

    @abstractmethod
    async def connect(self) -> None:
        """Opens (or reopens) the connection to the device."""

    async def close(self) -> None:
        """Releases resources. Optional."""

    @abstractmethod
    async def capabilities(self) -> Capabilities:
        """What this device supports. Called once per connection."""

    @abstractmethod
    async def read_state(self) -> DeviceState:
        """Reads the device's current state."""

    @abstractmethod
    async def apply(self, changes: Changes) -> None:
        """Sends the changes to the device."""
