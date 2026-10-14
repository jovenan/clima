import SwiftUI

/// Eco and Turbo, each only if the device supports it.
struct TogglesSection: View {
    @EnvironmentObject private var store: ClimateStore
    let state: DeviceState
    let capabilities: Capabilities

    static func isVisible(_ capabilities: Capabilities) -> Bool {
        capabilities.supportsAny(.eco, .turbo)
    }

    var body: some View {
        HStack(spacing: 8) {
            if capabilities.supports(.eco) {
                chip("Eco", symbol: "leaf.fill", on: state.eco, color: .green) {
                    store.apply(Changes(eco: !state.eco))
                }
            }
            if capabilities.supports(.turbo) {
                chip("Turbo", symbol: "bolt.fill", on: state.turbo, color: .orange) {
                    store.apply(Changes(turbo: !state.turbo))
                }
            }
        }
    }

    private func chip(_ title: String, symbol: String, on: Bool, color: Color,
                      action: @escaping () -> Void) -> some View {
        Tile(selected: on, color: color, height: 34, action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(on ? "ON" : "OFF").font(.system(size: 9, weight: .bold)).opacity(0.8)
            }
            .padding(.horizontal, 12)
        }
    }
}
