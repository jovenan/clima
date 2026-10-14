import SwiftUI

/// "Auto" + intensity bars, only with the speeds the device supports.
struct FanSection: View {
    @EnvironmentObject private var store: ClimateStore
    let state: DeviceState
    let capabilities: Capabilities

    private var levels: [(key: String, label: String)] {
        Style.fanLevels.filter { capabilities.fanSpeeds.contains($0.key) }
    }

    var body: some View {
        let tint = store.tint
        let isAuto = state.fanSpeed == "auto"
        let current = levels.firstIndex { $0.key == state.fanSpeed }
        // Speed outside the list: the device controls it itself (e.g. Midea in Dry mode)
        let summary = isAuto ? "Auto" : current.map { levels[$0].label } ?? "set by the device"

        VStack(spacing: 8) {
            SectionTitle(title: "Fan", trailing: summary)
            HStack(spacing: 8) {
                if capabilities.fanSpeeds.contains("auto") {
                    Tile(selected: isAuto, color: tint, height: 34) {
                        store.apply(Changes(fanSpeed: "auto"))
                    } content: {
                        Text("Auto").font(.system(size: 11, weight: .semibold))
                    }
                    .frame(width: 58)
                }
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                        bar(index: index, filled: !isAuto && (current ?? -1) >= index, tint: tint) {
                            store.apply(Changes(fanSpeed: level.key))
                        }
                        .help(level.label)
                    }
                }
                .frame(height: 34)
            }
        }
    }

    private func bar(index: Int, filled: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(filled ? tint : Color.primary.opacity(0.12))
                .frame(height: 10 + CGFloat(index) * 6)
                .frame(maxWidth: .infinity, maxHeight: 34, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}
