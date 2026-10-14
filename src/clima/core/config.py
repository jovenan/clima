"""User configuration (`~/.config/clima/config.json`).

Format:
    {
      "provider": "midea",
      "settings": { ... provider-specific ... },
      "disabled_features": ["turbo"]      # optional: hides features in the widget and the CLI
    }

The `CLIMA_CONFIG` environment variable overrides the path (useful for development).
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .errors import ConfigError
from .models import Feature

DEFAULT_PATH = Path.home() / ".config" / "clima" / "config.json"


def config_path() -> Path:
    return Path(os.environ.get("CLIMA_CONFIG", DEFAULT_PATH)).expanduser()


@dataclass
class Config:
    provider: str
    settings: dict[str, Any] = field(default_factory=dict)
    disabled_features: frozenset[Feature] = frozenset()

    @classmethod
    def load(cls, path: Path | None = None) -> Config:
        path = path or config_path()
        if not path.exists():
            raise ConfigError(f"configuration not found at {path}. Run 'clima setup'.")
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError as e:
            raise ConfigError(f"invalid configuration at {path}: {e}") from None
        return cls.from_dict(data)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Config:
        if not isinstance(data, dict) or not isinstance(data.get("provider"), str):
            raise ConfigError("configuration needs the 'provider' field")
        try:
            disabled = frozenset(Feature(f) for f in data.get("disabled_features", []))
        except ValueError as e:
            valid = ", ".join(f.value for f in Feature)
            raise ConfigError(f"disabled_features: {e}. Valid: {valid}") from None
        return cls(provider=data["provider"], settings=dict(data.get("settings", {})), disabled_features=disabled)

    def to_dict(self) -> dict[str, Any]:
        return {
            "provider": self.provider,
            "settings": self.settings,
            "disabled_features": sorted(f.value for f in self.disabled_features),
        }

    def save(self, path: Path | None = None) -> Path:
        path = path or config_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2) + "\n")
        os.chmod(path, 0o600)  # may contain device tokens
        return path
