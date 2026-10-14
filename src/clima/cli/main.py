"""Entry point of the `clima` command."""

from __future__ import annotations

import asyncio
import json
import sys
from typing import Awaitable, Callable

from ..core import ClimaError, Config, registry
from ..factory import build_service
from . import parser
from .formatting import format_status
from .parser import ApplyChanges, Command, ListProviders, RunSetup, ShowHelp, ShowStatus, UsageError
from .terminal import TerminalIO

HELP = f"""clima — control your air conditioner from the terminal

Usage:
  clima [status] [--json]          show the current state
  clima setup [--provider NAME]    configure the device (interactive)
  clima providers                  list the available providers
  clima <commands...> [--json]     change the device

Commands:
{parser.GRAMMAR}

Examples:
  clima on cool 23 fan auto
  clima vertical 2 horizontal swing
  clima clean on
"""


def main(argv: list[str] | None = None) -> int:
    try:
        command = parser.parse(sys.argv[1:] if argv is None else argv)
    except UsageError as e:
        return _fail(f"{e}\n\nSee 'clima help'.")
    try:
        return asyncio.run(run(command))
    except KeyboardInterrupt:
        return 130


async def run(command: Command) -> int:
    handlers: dict[type, Callable[[Command], Awaitable[int]]] = {
        ShowHelp: _help,
        ListProviders: _list_providers,
        RunSetup: _setup,
        ShowStatus: _status,
        ApplyChanges: _apply,
    }
    try:
        return await handlers[type(command)](command)
    except ClimaError as e:
        return _fail(str(e))


# ---------------------------------------------------------------- commands

async def _help(_: ShowHelp) -> int:
    print(HELP)
    return 0


async def _list_providers(_: ListProviders) -> int:
    for name, provider in registry.available().items():
        print(f"{name:<10} {provider.display_name}")
    for module, reason in registry.unavailable().items():
        print(f"{'(unavail.)':<10} {module}: {reason}")
    return 0


async def _setup(command: RunSetup) -> int:
    if not sys.stdin.isatty():
        return _fail("'clima setup' requires an interactive terminal")
    io = TerminalIO()
    name = command.provider or _choose_provider(io)
    provider_class = registry.get(name)
    settings = await provider_class.interactive_setup(io)
    path = Config(provider=name, settings=settings).save()
    print(f"OK! Configuration saved to {path}")
    return 0


async def _status(command: ShowStatus) -> int:
    service = build_service()
    try:
        _print_snapshot(await service.snapshot(), command.json)
    finally:
        await service.close()
    return 0


async def _apply(command: ApplyChanges) -> int:
    service = build_service()
    try:
        _print_snapshot(await service.apply(command.changes), command.json)
    finally:
        await service.close()
    return 0


# ---------------------------------------------------------------- helpers

def _choose_provider(io: TerminalIO) -> str:
    names = list(registry.available())
    if len(names) == 1:
        return names[0]
    for name, provider in registry.available().items():
        io.info(f"  {name:<10} {provider.display_name}")
    return io.ask("Provider", default="midea" if "midea" in names else names[0])


def _print_snapshot(snapshot, as_json: bool) -> None:
    print(json.dumps(snapshot.to_dict(), indent=2, ensure_ascii=False) if as_json else format_status(snapshot))


def _fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
