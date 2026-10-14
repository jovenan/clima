"""Midea provider (and brands using the same protocol: Springer Midea, Carrier, Comfee...).

Talks directly to the device over the local network (protocol V3, port 6444)
using the `msmart-ng` library. The cloud is used only once, during
`clima setup`, to obtain the device's token/key.
"""

from .provider import MideaProvider

__all__ = ["MideaProvider"]
