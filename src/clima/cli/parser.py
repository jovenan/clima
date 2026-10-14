"""Turns terminal arguments into a command. Pure function, no I/O (see `GRAMMAR`)."""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..core import Changes, FanSpeed, Mode

GRAMMAR = """\
  on | off                         power on / off
  auto | cool | dry | heat | fan   mode (turns the unit on, unless the command has `off`)
  <number>                         target temperature, e.g. 22 or 22.5
  fan <speed>                      auto | silent | low | medium | high | max
  swing off|vertical|horizontal|both
  vertical swing|stop|<position>   up/down louvers (swing, stop, fixed position)
  horizontal swing|stop|<position> left/right louvers
  eco on|off   turbo on|off   clean on|off (self-clean)

  Words can be combined; the ones on the right take precedence."""

NUMBER = re.compile(r"^\d+(\.\d+)?$")
ON_OFF = ("on", "off")
SWING_PRESETS = {
    "off": (False, False),
    "vertical": (True, False),
    "horizontal": (False, True),
    "both": (True, True),
}
TOGGLES = {"eco": "eco", "turbo": "turbo", "clean": "self_clean"}


class UsageError(ValueError):
    """Invalid arguments; the message is shown to the user."""


# ---------------------------------------------------------------- commands (parse result)

@dataclass(frozen=True)
class ShowHelp:
    pass


@dataclass(frozen=True)
class ListProviders:
    pass


@dataclass(frozen=True)
class RunSetup:
    provider: str | None = None


@dataclass(frozen=True)
class ShowStatus:
    json: bool = False


@dataclass(frozen=True)
class ApplyChanges:
    changes: Changes = field(default_factory=Changes)
    json: bool = False


Command = ShowHelp | ListProviders | RunSetup | ShowStatus | ApplyChanges


# ---------------------------------------------------------------- parse

def parse(argv: list[str]) -> Command:
    args = [a.lower() for a in argv]
    as_json = "--json" in args
    args = [a for a in args if a != "--json"]

    if not args or args == ["status"]:
        return ShowStatus(json=as_json)
    if args[0] in ("help", "-h", "--help"):
        return ShowHelp()
    if args == ["providers"]:
        return ListProviders()
    if args[0] == "setup":
        return _parse_setup(args[1:])
    return ApplyChanges(changes=parse_changes(args), json=as_json)


def _parse_setup(args: list[str]) -> RunSetup:
    if not args:
        return RunSetup()
    if len(args) == 2 and args[0] == "--provider":
        return RunSetup(provider=args[1])
    raise UsageError("usage: clima setup [--provider NAME]")


def parse_changes(tokens: list[str]) -> Changes:
    """Reads tokens left to right; later tokens take precedence."""
    changes = Changes()
    picked_mode = False
    i = 0
    while i < len(tokens):
        token, value = tokens[i], tokens[i + 1] if i + 1 < len(tokens) else None
        step, consumed = _parse_token(token, value)
        picked_mode |= step.mode is not None
        changes = changes.merged(step)
        i += consumed

    # Picking a mode turns the unit on, unless the command itself asks for `off`
    if picked_mode and changes.power is None:
        changes = changes.merged(Changes(power=True))
    return changes


def _parse_token(token: str, value: str | None) -> tuple[Changes, int]:
    """Interprets a token (and the next one, if it is a value). Returns (change, tokens consumed)."""
    if token in ON_OFF:
        return Changes(power=token == "on"), 1
    if token == "fan" and value in _values(FanSpeed):
        return Changes(fan_speed=FanSpeed(value)), 2
    if token in _values(Mode):
        return Changes(mode=Mode(token)), 1
    if NUMBER.match(token):
        return Changes(target_temperature=float(token)), 1
    if token == "swing":
        vertical, horizontal = SWING_PRESETS[_require(token, value, SWING_PRESETS)]
        return Changes(swing_vertical=vertical, swing_horizontal=horizontal), 2
    if token in ("vertical", "horizontal"):
        return _parse_louver(token, value), 2
    if token in TOGGLES:
        return Changes(**{TOGGLES[token]: _require(token, value, ON_OFF) == "on"}), 2
    raise UsageError(f"unknown argument: {token}")


def _parse_louver(axis: str, value: str | None) -> Changes:
    if value in ("swing", "stop"):
        return Changes(**{f"swing_{axis}": value == "swing"})
    if value is not None and value.isdigit():
        return Changes(**{f"louver_{axis}": int(value)})
    raise UsageError(f"{axis}: use swing | stop | <position>")


def _require(token: str, value: str | None, choices) -> str:
    if value not in choices:
        raise UsageError(f"{token}: use {' | '.join(choices)}")
    return value


def _values(enum) -> set[str]:
    return {e.value for e in enum}
