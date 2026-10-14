/// Where the app reads state from and sends commands to (implemented by `BridgeProcess`).
public protocol ClimateBackend: AnyObject {
    func snapshot() async throws -> Snapshot
    func apply(_ changes: Changes) async throws -> Snapshot
}

public struct BackendError: Error, Equatable {
    public enum Kind: String, Sendable {
        case invalid, device, config
        case unexpected = "internal"
        case transport  // failed to talk to the bridge process
    }

    public let message: String
    public let kind: Kind

    public init(_ message: String, kind: Kind) {
        self.message = message
        self.kind = kind
    }
}
