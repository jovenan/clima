"""Bridge protocol. Each input line is a request; each output line, a response.

Requests:
    {"id": 1, "op": "snapshot"}
    {"id": 2, "op": "apply", "changes": {"power": true, "target_temperature": 23}}

Responses:
    {"id": 1, "ok": true, "state": {...}, "capabilities": {...}}
    {"id": 2, "ok": false, "error": "message", "kind": "invalid" | "device" | "config" | "internal"}
"""

from __future__ import annotations

import logging
from typing import Any, Awaitable, Callable

from ..core import Changes, ClimateService, ConfigError, DeviceError, InvalidRequest

log = logging.getLogger(__name__)

ServiceFactory = Callable[[], ClimateService]


class BridgeHandler:
    """Dispatches each `op` to the matching method (Command pattern)."""

    def __init__(self, service_factory: ServiceFactory) -> None:
        self._service_factory = service_factory
        self._service: ClimateService | None = None
        self._ops: dict[str, Callable[[dict[str, Any]], Awaitable[dict[str, Any]]]] = {
            "snapshot": self._snapshot,
            "apply": self._apply,
        }

    async def handle(self, request: Any) -> dict[str, Any]:
        request_id = request.get("id") if isinstance(request, dict) else None
        try:
            if not isinstance(request, dict):
                raise InvalidRequest("request must be a JSON object")
            op = self._ops.get(request.get("op"))
            if op is None:
                raise InvalidRequest(f"unknown op: {request.get('op')!r}")
            response = {"ok": True, **await op(request)}
        except Exception as e:
            response = _error_response(e)
        return {"id": request_id, **response}

    async def close(self) -> None:
        if self._service:
            await self._service.close()

    # ---------------------------------------------------------------- ops

    async def _snapshot(self, _: dict[str, Any]) -> dict[str, Any]:
        return (await self._get_service().snapshot()).to_dict()

    async def _apply(self, request: dict[str, Any]) -> dict[str, Any]:
        changes = Changes.from_dict(request.get("changes"))
        return (await self._get_service().apply(changes)).to_dict()

    def _get_service(self) -> ClimateService:
        # Created on demand: if the configuration is missing, each request returns the "config" error
        if self._service is None:
            self._service = self._service_factory()
        return self._service


def _error_response(error: Exception) -> dict[str, Any]:
    kinds = [(InvalidRequest, "invalid"), (DeviceError, "device"), (ConfigError, "config")]
    kind = next((name for cls, name in kinds if isinstance(error, cls)), "internal")
    if kind == "internal":
        log.exception("unexpected error in the bridge")
    return {"ok": False, "error": str(error) or type(error).__name__, "kind": kind}
