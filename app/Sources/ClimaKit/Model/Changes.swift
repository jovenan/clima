/// Change request sent to the bridge. `nil` fields are not sent ("leave unchanged").
public struct Changes: Encodable, Equatable, Sendable {
    public var power: Bool?
    public var mode: String?
    public var targetTemperature: Double?
    public var fanSpeed: String?
    public var swingVertical: Bool?
    public var swingHorizontal: Bool?
    public var louverVertical: Int?
    public var louverHorizontal: Int?
    public var eco: Bool?
    public var turbo: Bool?
    public var selfClean: Bool?

    public init(power: Bool? = nil, mode: String? = nil, targetTemperature: Double? = nil, fanSpeed: String? = nil,
                swingVertical: Bool? = nil, swingHorizontal: Bool? = nil, louverVertical: Int? = nil,
                louverHorizontal: Int? = nil, eco: Bool? = nil, turbo: Bool? = nil, selfClean: Bool? = nil) {
        self.power = power
        self.mode = mode
        self.targetTemperature = targetTemperature
        self.fanSpeed = fanSpeed
        self.swingVertical = swingVertical
        self.swingHorizontal = swingHorizontal
        self.louverVertical = louverVertical
        self.louverHorizontal = louverHorizontal
        self.eco = eco
        self.turbo = turbo
        self.selfClean = selfClean
    }
}
