import SwiftUI

/// Self-clean. Starting takes two taps (a long cycle should not start by accident).
struct SelfCleanSection: View {
    @EnvironmentObject private var store: ClimateStore
    let state: DeviceState
    @State private var confirming = false

    var body: some View {
        let active = state.selfClean
        Tile(selected: active || confirming, color: Style.clean, height: 44, action: tap) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolEffect(.pulse, isActive: active)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Self-clean").font(.system(size: 12, weight: .semibold))
                    Text(subtitle(active: active)).font(.system(size: 10)).opacity(0.8)
                }
                Spacer()
                Image(systemName: active ? "stop.circle" : "chevron.right")
                    .font(.system(size: active ? 14 : 10, weight: .bold))
                    .opacity(active ? 0.9 : 0.5)
            }
            .padding(.horizontal, 12)
        }
        .animation(.snappy(duration: 0.2), value: confirming)
    }

    private func subtitle(active: Bool) -> String {
        if active { return "Running · tap to stop" }
        return confirming ? "Tap again to start" : "Cleans and dries the indoor coil"
    }

    private func tap() {
        if state.selfClean {
            store.apply(Changes(selfClean: false))
        } else if confirming {
            confirming = false
            store.apply(Changes(selfClean: true))
        } else {
            confirming = true
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                confirming = false
            }
        }
    }
}
