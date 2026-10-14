"""Provider registry (Registry + Factory patterns).

Built-in providers register themselves with the `@register` decorator. Providers
from external packages are discovered through the `clima.providers` entry point,
without changing this project:

    # your package's pyproject.toml
    [project.entry-points."clima.providers"]
    my_vendor = "my_package.provider:MyProvider"
"""

from __future__ import annotations

import importlib
import logging
from importlib.metadata import entry_points
from typing import Any, Mapping, TypeVar

from .errors import ConfigError
from .provider import ClimateProvider

log = logging.getLogger(__name__)

ENTRY_POINT_GROUP = "clima.providers"
BUILTIN_PROVIDERS = ("clima.providers.demo", "clima.providers.midea")

_providers: dict[str, type[ClimateProvider]] = {}
_unavailable: dict[str, str] = {}  # module -> reason (e.g. dependency not installed)
_loaded = False

P = TypeVar("P", bound=type[ClimateProvider])


def register(cls: P) -> P:
    """Decorator that registers a provider by its `name`."""
    if not getattr(cls, "name", None):
        raise TypeError(f"{cls.__name__} must define the 'name' attribute")
    _providers[cls.name] = cls
    return cls


def available() -> dict[str, type[ClimateProvider]]:
    """Providers ready to use, by name."""
    _load()
    return dict(sorted(_providers.items()))


def unavailable() -> dict[str, str]:
    """Providers that could not be loaded, and why."""
    _load()
    return dict(_unavailable)


def get(name: str) -> type[ClimateProvider]:
    _load()
    if name in _providers:
        return _providers[name]
    hint = f" Available: {', '.join(_providers) or 'none'}."
    raise ConfigError(f"unknown provider: '{name}'.{hint}")


def create(name: str, settings: Mapping[str, Any]) -> ClimateProvider:
    return get(name)(settings)


def _load() -> None:
    global _loaded
    if _loaded:
        return
    _loaded = True
    for module in BUILTIN_PROVIDERS:
        _import(module)
    for ep in entry_points(group=ENTRY_POINT_GROUP):
        try:
            register(ep.load())
        except Exception as e:  # a broken plugin must not take the others down
            _unavailable[ep.value] = str(e)
            log.warning("could not load provider %s: %s", ep.value, e)


def _import(module: str) -> None:
    try:
        importlib.import_module(module)
    except ImportError as e:
        _unavailable[module] = f"missing dependency: {e.name or e}"
