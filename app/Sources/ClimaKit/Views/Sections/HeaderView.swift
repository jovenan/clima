import SwiftUI

/// Icon, name, sensor readings and the power button.
struct HeaderView: View {
    @EnvironmentObject private var store: ClimateStore

    var body: some View {
        let state = store.state
        let on = state?.power == true
        HStack(spacing: 12) {
            Image(systemName: "air.conditioner.horizontal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(on ? store.tint : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((on ? store.tint : Color.secondary).opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Air conditioner").font(.system(size: 14, weight: .semibold))
                sensors
            }

            Spacer()

            if let state, store.capabilities?.supports(.power) == true {
                CircleButton(symbol: "power", size: 38, filled: state.power, color: store.tint) {
                    store.apply(Changes(power: !state.power))
                }
                .help(state.power ? "Turn off" : "Turn on")
            }
        }
    }

    @ViewBuilder private var sensors: some View {
        if let state = store.state, let caps = store.capabilities {
            HStack(spacing: 8) {
                if caps.supports(.indoorTemperature), let value = state.indoorTemperature {
                    Label("\(Style.temperature(value))°", systemImage: "house.fill")
                }
                if caps.supports(.outdoorTemperature), let value = state.outdoorTemperature {
                    Label("\(Style.temperature(value))°", systemImage: "sun.max.fill")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .labelStyle(CompactLabel())
        }
    }
}
