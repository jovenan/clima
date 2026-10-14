/// State + capabilities: everything the UI needs to draw itself.
public struct Snapshot: Codable, Equatable, Sendable {
    public var state: DeviceState
    public var capabilities: Capabilities

    public init(state: DeviceState, capabilities: Capabilities) {
        self.state = state
        self.capabilities = capabilities
    }
}
