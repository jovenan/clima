/// Current reading of the device.
public struct DeviceState: Codable, Equatable, Sendable {
    public var power: Bool
    public var mode: String?
    public var targetTemperature: Double?
    public var indoorTemperature: Double?
    public var outdoorTemperature: Double?
    public var fanSpeed: String?
    public var swingVertical: Bool
    public var swingHorizontal: Bool
    public var louverVertical: Int?
    public var louverHorizontal: Int?
    public var eco: Bool
    public var turbo: Bool
    public var selfClean: Bool

    public init(power: Bool = false, mode: String? = nil, targetTemperature: Double? = nil,
                indoorTemperature: Double? = nil, outdoorTemperature: Double? = nil, fanSpeed: String? = nil,
                swingVertical: Bool = false, swingHorizontal: Bool = false, louverVertical: Int? = nil,
                louverHorizontal: Int? = nil, eco: Bool = false, turbo: Bool = false, selfClean: Bool = false) {
        self.power = power
        self.mode = mode
        self.targetTemperature = targetTemperature
        self.indoorTemperature = indoorTemperature
        self.outdoorTemperature = outdoorTemperature
        self.fanSpeed = fanSpeed
        self.swingVertical = swingVertical
        self.swingHorizontal = swingHorizontal
        self.louverVertical = louverVertical
        self.louverHorizontal = louverHorizontal
        self.eco = eco
        self.turbo = turbo
        self.selfClean = selfClean
    }

    /// Fan mode does not use a target temperature.
    public var usesTargetTemperature: Bool { power && mode != "fan" }

    /// Predicts the result of a request so the UI can react before the device answers.
    /// Follows the same domain rules as Python (fixing a louver stops swinging; swinging clears the position).
    public func applying(_ changes: Changes) -> DeviceState {
        var s = self
        if let v = changes.power { s.power = v; if v { s.selfClean = false } }
        if let v = changes.mode { s.mode = v }
        if let v = changes.targetTemperature { s.targetTemperature = v }
        if let v = changes.fanSpeed { s.fanSpeed = v }
        if let v = changes.louverVertical { s.louverVertical = v; s.swingVertical = false }
        if let v = changes.louverHorizontal { s.louverHorizontal = v; s.swingHorizontal = false }
        if let v = changes.swingVertical { s.swingVertical = v; if v { s.louverVertical = nil } }
        if let v = changes.swingHorizontal { s.swingHorizontal = v; if v { s.louverHorizontal = nil } }
        if let v = changes.eco { s.eco = v }
        if let v = changes.turbo { s.turbo = v }
        if let v = changes.selfClean { s.selfClean = v; if v { s.power = false } }
        return s
    }
}
