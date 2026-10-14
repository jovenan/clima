"""Clima core: models, provider contract, validation and service. Vendor-independent."""

from .config import Config, config_path
from .errors import ClimaError, ConfigError, DeviceError, InvalidRequest, UnsupportedFeature
from .models import Capabilities, Changes, DeviceState, FanSpeed, Feature, Mode
from .provider import ClimateProvider, SetupIO
from .registry import register
from .service import ClimateService, RetryPolicy, Snapshot

__all__ = [
    "Capabilities", "Changes", "ClimaError", "ClimateProvider", "ClimateService", "Config", "ConfigError",
    "DeviceError", "DeviceState", "FanSpeed", "Feature", "InvalidRequest", "Mode", "RetryPolicy", "SetupIO",
    "Snapshot", "UnsupportedFeature", "config_path", "register",
]
