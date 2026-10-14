import SwiftUI

/// One button per mode the device supports.
struct ModeSection: View {
    @EnvironmentObject private var store: ClimateStore
    let state: DeviceState
    let capabilities: Capabilities

    var body: some View {
        VStack(spacing: 8) {
            SectionTitle(title: "Mode")
            HStack(spacing: 6) {
                ForEach(capabilities.modes, id: \.self) { mode in
                    let style = Style.mode(mode)
                    Tile(selected: state.mode == mode, color: style.color, height: 54) {
                        store.apply(Changes(mode: mode))
                    } content: {
                        VStack(spacing: 5) {
                            Image(systemName: style.symbol).font(.system(size: 16, weight: .semibold))
                            Text(style.label).font(.system(size: 10, weight: .medium))
                        }
                    }
                }
            }
        }
    }
}
