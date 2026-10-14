import SwiftUI

/// What shows in the menu bar: mode icon + target temperature, or just an icon.
public struct MenuBarLabel: View {
    @ObservedObject private var store: ClimateStore

    public init(store: ClimateStore) {
        self.store = store
    }

    public var body: some View {
        if let state = store.state {
            let symbol = store.capabilities?.supports(.mode) == true ? Style.mode(state.mode).symbol : "power"
            if state.selfClean {
                Image(systemName: "sparkles")
            } else if state.power, state.usesTargetTemperature, let target = state.targetTemperature {
                Text("\(Image(systemName: symbol)) \(Style.temperature(target))°")
            } else if state.power {
                Image(systemName: symbol)
            } else {
                Image(systemName: "air.conditioner.horizontal")
            }
        } else if store.error != nil {
            Image(systemName: "exclamationmark.triangle")
        } else {
            Image(systemName: "air.conditioner.horizontal")
        }
    }
}
