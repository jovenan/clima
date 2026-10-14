/// What the device supports. Each panel section only appears if its feature is listed here.
public struct Capabilities: Codable, Equatable, Sendable {
    /// Raw names from the bridge: features unknown to this app version are ignored.
    public var features: Set<String>
    public var modes: [String]
    public var fanSpeeds: [String]
    public var minTemperature: Double
    public var maxTemperature: Double
    public var temperatureStep: Double
    public var louverPositions: Int

    public init(features: Set<Feature>, modes: [String] = [], fanSpeeds: [String] = [],
                minTemperature: Double = 16, maxTemperature: Double = 30, temperatureStep: Double = 0.5,
                louverPositions: Int = 5) {
        self.features = Set(features.map(\.rawValue))
        self.modes = modes
        self.fanSpeeds = fanSpeeds
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.temperatureStep = temperatureStep
        self.louverPositions = louverPositions
    }

    public func supports(_ feature: Feature) -> Bool {
        features.contains(feature.rawValue)
    }

    public func supportsAny(_ list: Feature...) -> Bool {
        list.contains(where: supports)
    }
}
