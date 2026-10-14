"""Composition root: builds the `ClimateService` from the user's configuration."""

from __future__ import annotations

from .core import ClimateService, Config
from .core import registry


def build_service(config: Config | None = None) -> ClimateService:
    config = config or Config.load()
    provider = registry.create(config.provider, config.settings)
    return ClimateService(provider, disabled_features=config.disabled_features)
