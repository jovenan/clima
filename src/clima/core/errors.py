"""Clima error hierarchy.

The distinction matters to `ClimateService`: *request* errors are never retried
(trying again changes nothing), while *device* errors trigger a reconnect and
another attempt.
"""


class ClimaError(Exception):
    """Base of all Clima errors."""


class InvalidRequest(ClimaError):
    """The request is invalid (value out of range, wrong type, unknown field)."""


class UnsupportedFeature(InvalidRequest):
    """The request uses a feature the provider (or the configuration) does not offer."""


class DeviceError(ClimaError):
    """Communication failure with the device. May be temporary: worth reconnecting."""


class ConfigError(ClimaError):
    """Missing or invalid configuration."""
