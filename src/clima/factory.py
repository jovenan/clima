"""Composition root: builds the `ClimateService` from the user's configuration."""

from __future__ import annotations

import logging
from typing import Any

from .core import ClimateService, Config
from .core import registry

log = logging.getLogger(__name__)


def build_service(config: Config | None = None) -> ClimateService:
    config = config or Config.load()
    provider = registry.create(config.provider, config.settings)
    provider.on_settings_changed = lambda settings: _save_settings(config, settings)
    return ClimateService(provider, disabled_features=config.disabled_features)


def _save_settings(config: Config, settings: dict[str, Any]) -> None:
    config.settings = settings
    try:
        config.save()
    except OSError as e:
        log.warning("could not save the updated configuration: %s", e)
