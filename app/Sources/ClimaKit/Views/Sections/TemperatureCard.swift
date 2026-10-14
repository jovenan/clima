import SwiftUI

/// Central card: target temperature with −/+, or the state (off, cleaning, fan only).
struct TemperatureCard: View {
    @EnvironmentObject private var store: ClimateStore
    let state: DeviceState
    let capabilities: Capabilities

    private var adjustable: Bool { capabilities.supports(.targetTemperature) }

    var body: some View {
        let tint = store.tint
        HStack {
            if adjustable {
                CircleButton(symbol: "minus") { store.stepTarget(-1) }
                    .disabled(!state.usesTargetTemperature
                              || (state.targetTemperature ?? 0) <= capabilities.minTemperature)
            }
            Spacer()
            center(tint: tint).frame(height: 90)
            Spacer()
            if adjustable {
                CircleButton(symbol: "plus") { store.stepTarget(+1) }
                    .disabled(!state.usesTargetTemperature
                              || (state.targetTemperature ?? .infinity) >= capabilities.maxTemperature)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [tint.opacity(state.power ? 0.30 : 0.06), tint.opacity(state.power ? 0.08 : 0.02)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(state.power ? 0.3 : 0.1), lineWidth: 1)
        )
    }

    @ViewBuilder private func center(tint: Color) -> some View {
        VStack(spacing: 0) {
            if state.selfClean {
                headline("Cleaning", color: Style.clean)
                caption("self-clean running")
            } else if !state.power {
                headline("Off", color: .secondary)
                caption("tap \(Image(systemName: "power")) to turn on")
            } else if !state.usesTargetTemperature || !adjustable {
                Image(systemName: capabilities.supports(.mode) ? Style.mode(state.mode).symbol : "power")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse)
                caption(state.usesTargetTemperature ? "on" : "fan only, no target temperature")
                    .padding(.top, 4)
            } else {
                HStack(alignment: .top, spacing: 1) {
                    Text(Style.temperature(state.targetTemperature))
                        .font(.system(size: 58, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: state.targetTemperature ?? 0))
                    Text("°C")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
                caption("target temperature")
            }
        }
    }

    private func headline(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 24, weight: .medium, design: .rounded)).foregroundStyle(color)
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).padding(.top, 4)
    }
}
