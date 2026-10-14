"""`ClimateService`: the facade used by the CLI and the widget bridge.

Responsibilities:
- keep the provider connection open and reopen it when it drops;
- validate requests against the capabilities before sending them;
- retry communication failures (never invalid requests);
- hide features disabled by the user (`disabled_features`).
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Iterable, TypeVar

from .errors import DeviceError
from .models import Capabilities, Changes, DeviceState, Feature
from .provider import ClimateProvider
from .validation import validate

log = logging.getLogger(__name__)

T = TypeVar("T")

#: Errors that indicate a communication failure (worth reconnecting and retrying)
RETRYABLE_ERRORS = (DeviceError, OSError, asyncio.TimeoutError)


@dataclass(frozen=True)
class Snapshot:
    """State + capabilities: everything an interface needs to draw itself."""

    state: DeviceState
    capabilities: Capabilities

    def to_dict(self) -> dict[str, Any]:
        return {"state": self.state.to_dict(), "capabilities": self.capabilities.to_dict()}


@dataclass(frozen=True)
class RetryPolicy:
    attempts: int = 3
    base_delay: float = 1.0

    def delay(self, attempt: int) -> float:
        """Growing delay: 1 s, 3 s, 5 s..."""
        return self.base_delay * (1 + 2 * attempt)


class ClimateService:
    def __init__(
        self,
        provider: ClimateProvider,
        *,
        disabled_features: Iterable[Feature] = (),
        retry: RetryPolicy = RetryPolicy(),
        sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        self.provider = provider
        self._disabled = frozenset(disabled_features)
        self._retry = retry
        self._sleep = sleep
        self._capabilities: Capabilities | None = None

    async def capabilities(self) -> Capabilities:
        await self._call(None)
        assert self._capabilities is not None
        return self._capabilities

    async def snapshot(self) -> Snapshot:
        state = await self._call(lambda p: p.read_state())
        return Snapshot(state, await self.capabilities())

    async def apply(self, changes: Changes) -> Snapshot:
        """Validates, sends, and returns the resulting state."""
        valid = validate(changes, await self.capabilities())
        await self._call(lambda p: p.apply(valid))
        return await self.snapshot()

    async def close(self) -> None:
        self._capabilities = None
        await self.provider.close()

    # ------------------------------------------------------------------ internals

    async def _ensure_connected(self) -> None:
        if self._capabilities is None:
            await self.provider.connect()
            self._capabilities = (await self.provider.capabilities()).without(self._disabled)

    async def _call(self, operation: Callable[[ClimateProvider], Awaitable[T]] | None) -> T | None:
        last_error: Exception | None = None
        for attempt in range(self._retry.attempts):
            try:
                await self._ensure_connected()
                return await operation(self.provider) if operation else None
            except RETRYABLE_ERRORS as e:
                last_error = e
                self._capabilities = None  # forces a reconnect on the next attempt
                log.info("communication failure (attempt %d): %s", attempt + 1, e)
                if attempt + 1 < self._retry.attempts:
                    await self._sleep(self._retry.delay(attempt))
        raise DeviceError(f"the device did not respond ({last_error})") from last_error
