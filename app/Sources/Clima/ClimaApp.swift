import ClimaKit
import Foundation
import SwiftUI

/// Menu bar app. The `CLIMA_BRIDGE` variable overrides the bridge executable (useful in development).
@main
struct ClimaApp: App {
    @StateObject private var store = ClimateStore(backend: BridgeProcess(executable: bridgeExecutable()))

    var body: some Scene {
        MenuBarExtra {
            ClimatePanel().environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

private func bridgeExecutable() -> URL {
    if let path = ProcessInfo.processInfo.environment["CLIMA_BRIDGE"] {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
    return BridgeProcess.defaultExecutable
}
