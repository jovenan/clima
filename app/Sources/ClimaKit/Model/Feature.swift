/// Features a provider may offer (same names as Python's `Feature`).
public enum Feature: String, CaseIterable, Sendable {
    case power
    case targetTemperature = "target_temperature"
    case mode
    case fanSpeed = "fan_speed"
    case swingVertical = "swing_vertical"
    case swingHorizontal = "swing_horizontal"
    case louverVertical = "louver_vertical"
    case louverHorizontal = "louver_horizontal"
    case eco
    case turbo
    case selfClean = "self_clean"
    case indoorTemperature = "indoor_temperature"
    case outdoorTemperature = "outdoor_temperature"
}
