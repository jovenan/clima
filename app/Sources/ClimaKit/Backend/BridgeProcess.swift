import Foundation

/// Talks to `clima-bridge` (Python) over JSON, one message per line, via stdin/stdout.
///
/// - The process is started on demand and restarted if it dies.
/// - Each request has an `id`; responses may arrive out of order.
/// - Each request expires after `timeout` seconds.
public final class BridgeProcess: ClimateBackend {
    public static let defaultExecutable = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/clima/venv/bin/clima-bridge")

    private let executable: URL
    private let arguments: [String]
    private let environment: [String: String]
    private let timeout: TimeInterval

    private let lock = NSLock()
    private var process: Process?
    private var stdin: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: CheckedContinuation<Snapshot, Error>] = [:]

    public init(executable: URL = BridgeProcess.defaultExecutable, arguments: [String] = [],
                environment: [String: String] = [:], timeout: TimeInterval = 45) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.timeout = timeout
        // Writing to a pipe whose process died must not crash the app: it becomes an error from write()
        signal(SIGPIPE, SIG_IGN)
    }

    deinit { process?.terminate() }

    public func snapshot() async throws -> Snapshot {
        try await send(Request(op: "snapshot"))
    }

    public func apply(_ changes: Changes) async throws -> Snapshot {
        try await send(Request(op: "apply", changes: changes))
    }

    // MARK: - Messages

    private struct Request: Encodable {
        var id = 0
        let op: String
        var changes: Changes?
    }

    private struct Response: Decodable {
        let id: Int?
        let ok: Bool
        let state: DeviceState?
        let capabilities: Capabilities?
        let error: String?
        let kind: String?
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Sending

    private func send(_ request: Request) async throws -> Snapshot {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            let id = nextID
            nextID += 1
            do {
                try startIfNeeded()
                var request = request
                request.id = id
                var line = try Self.encoder.encode(request)
                line.append(0x0A)
                guard let stdin else { throw BackendError("bridge process unavailable", kind: .transport) }
                // Register only after writing: if the write fails, the continuation is resumed exactly once
                pending[id] = continuation
                do {
                    try stdin.write(contentsOf: line)
                } catch {
                    pending[id] = nil
                    throw error
                }
                lock.unlock()
                scheduleTimeout(for: id)
            } catch {
                lock.unlock()
                let message = (error as? BackendError)?.message ?? error.localizedDescription
                continuation.resume(throwing: BackendError("could not talk to the bridge (\(message))",
                                                           kind: .transport))
            }
        }
    }

    private func scheduleTimeout(for id: Int) {
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.resolve(id, .failure(BackendError("the device took too long to respond", kind: .device)))
        }
    }

    // MARK: - Process

    /// Called with `lock` held.
    private func startIfNeeded() throws {
        if let process, process.isRunning { return }

        let p = Process()
        p.executableURL = executable
        p.arguments = arguments
        p.environment = ProcessInfo.processInfo.environment
            .merging(environment) { _, new in new }
            .merging(["PYTHONUNBUFFERED": "1"]) { _, new in new }

        let input = Pipe()
        let output = Pipe()
        p.standardInput = input
        p.standardOutput = output
        p.standardError = FileHandle.standardError

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                self?.receive(data)
            }
        }
        p.terminationHandler = { [weak self] finished in self?.processDidExit(finished) }

        buffer = Data()
        try p.run()
        process = p
        stdin = input.fileHandleForWriting
    }

    private func processDidExit(_ finished: Process) {
        lock.lock()
        guard process === finished else {  // an old process; the current one is still alive
            lock.unlock()
            return
        }
        let waiting = pending
        pending = [:]
        process = nil
        stdin = nil
        lock.unlock()
        let error = BackendError("the bridge process exited", kind: .transport)
        waiting.values.forEach { $0.resume(throwing: error) }
    }

    // MARK: - Receiving

    private func receive(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            lines.append(Data(buffer[buffer.startIndex..<newline]))
            buffer = Data(buffer[buffer.index(after: newline)...])
        }
        lock.unlock()
        lines.forEach(handleLine)
    }

    private func handleLine(_ line: Data) {
        guard let response = try? Self.decoder.decode(Response.self, from: line), let id = response.id else {
            return  // not a protocol line (e.g. a library warning): ignore
        }
        if response.ok, let state = response.state, let capabilities = response.capabilities {
            resolve(id, .success(Snapshot(state: state, capabilities: capabilities)))
        } else {
            let kind = BackendError.Kind(rawValue: response.kind ?? "") ?? .unexpected
            resolve(id, .failure(BackendError(response.error ?? "unknown error", kind: kind)))
        }
    }

    private func resolve(_ id: Int, _ result: Result<Snapshot, Error>) {
        lock.lock()
        let continuation = pending.removeValue(forKey: id)
        lock.unlock()
        continuation?.resume(with: result)
    }
}
