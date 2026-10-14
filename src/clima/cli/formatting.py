"""Text for `clima status`. Only shows the lines the device supports."""

from __future__ import annotations

from ..core import Feature, Snapshot

MODE_LABELS = {"auto": "Auto", "cool": "Cool", "dry": "Dry", "heat": "Heat", "fan": "Fan"}
FAN_LABELS = {"auto": "Auto", "silent": "Silent", "low": "Low", "medium": "Medium", "high": "High", "max": "Max"}


def format_status(snapshot: Snapshot) -> str:
    s, caps = snapshot.state, snapshot.capabilities
    rows: list[tuple[str, str]] = [("Power", "on" if s.power else "off")]

    if caps.supports(Feature.MODE) and s.mode:
        rows.append(("Mode", MODE_LABELS.get(s.mode.value, s.mode.value)))
    if caps.supports(Feature.TARGET_TEMPERATURE):
        rows.append(("Target", _temp(s.target_temperature)))
    if caps.supports(Feature.INDOOR_TEMPERATURE):
        rows.append(("Indoor", _temp(s.indoor_temperature)))
    if caps.supports(Feature.OUTDOOR_TEMPERATURE) and s.outdoor_temperature is not None:
        rows.append(("Outdoor", _temp(s.outdoor_temperature)))
    if caps.supports(Feature.FAN_SPEED):
        # No known value: the device controls it on its own (e.g. Midea in Dry mode)
        rows.append(("Fan", FAN_LABELS[s.fan_speed.value] if s.fan_speed else "set by the device"))

    louvers = _louvers(snapshot)
    if louvers:
        rows.append(("Airflow", louvers))

    toggles = [(Feature.ECO, "Eco", s.eco), (Feature.TURBO, "Turbo", s.turbo),
               (Feature.SELF_CLEAN, "Self-clean", s.self_clean)]
    for feature, label, on in toggles:
        if caps.supports(feature):
            rows.append((label, "on" if on else "off"))

    width = max(len(label) for label, _ in rows) + 2
    return "\n".join(f"{label + ':':<{width}}{value}" for label, value in rows)


def _louvers(snapshot: Snapshot) -> str:
    s, caps = snapshot.state, snapshot.capabilities
    parts = []
    axes = [("↕", Feature.SWING_VERTICAL, Feature.LOUVER_VERTICAL, s.swing_vertical, s.louver_vertical),
            ("↔", Feature.SWING_HORIZONTAL, Feature.LOUVER_HORIZONTAL, s.swing_horizontal, s.louver_horizontal)]
    for arrow, swing_feature, louver_feature, swinging, position in axes:
        if not (caps.supports(swing_feature) or caps.supports(louver_feature)):
            continue
        if swinging:
            parts.append(f"{arrow} swinging")
        elif position:
            parts.append(f"{arrow} position {position}")
        else:
            parts.append(f"{arrow} stopped")
    return " · ".join(parts)


def _temp(value: float | None) -> str:
    return "—" if value is None else f"{value:g}°C"
