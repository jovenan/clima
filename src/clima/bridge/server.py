"""`clima-bridge` entry point: reads requests from stdin and answers on stdout, one per line."""

from __future__ import annotations

import asyncio
import json
import logging
import sys
from typing import TextIO

from ..factory import build_service
from .protocol import BridgeHandler


async def serve(handler: BridgeHandler, stdin: TextIO = sys.stdin, stdout: TextIO = sys.stdout) -> None:
    """Serves requests in order until stdin closes (the app quit)."""
    loop = asyncio.get_running_loop()
    try:
        while line := await loop.run_in_executor(None, stdin.readline):
            if not line.strip():
                continue
            try:
                request = json.loads(line)
            except json.JSONDecodeError as e:
                response = {"id": None, "ok": False, "error": f"invalid JSON: {e}", "kind": "invalid"}
            else:
                response = await handler.handle(request)
            stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
            stdout.flush()
    finally:
        await handler.close()


def main() -> None:
    # stdout is reserved for the protocol; logs go to stderr (the app writes them to ~/Library/Logs/clima.log)
    logging.basicConfig(stream=sys.stderr, level=logging.WARNING, format="%(asctime)s %(name)s: %(message)s")
    asyncio.run(serve(BridgeHandler(build_service)))


if __name__ == "__main__":
    main()
