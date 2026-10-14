import AppKit
import SwiftUI

/// The panel that opens when clicking the menu bar icon.
///
/// Each section only appears if the provider declares its feature in `Capabilities`;
/// switching brands (or disabling something in `disabled_features`) changes the panel by itself.
public struct ClimatePanel: View {
    @EnvironmentObject private var store: ClimateStore

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            HeaderView()
            if let error = store.error {
                ErrorBanner(error: error)
            }
            if let snapshot = store.snapshot {
                controls(snapshot.state, snapshot.capabilities)
            } else if store.error == nil {
                ProgressView().controlSize(.small).frame(height: 240)
            }
            Divider().opacity(0.5)
            FooterView()
        }
        .padding(16)
        .frame(width: 320)
        .animation(.snappy(duration: 0.25), value: store.snapshot)
        .animation(.snappy(duration: 0.25), value: store.error)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { store.stepTarget(+1); return .handled }
        .onKeyPress(.downArrow) { store.stepTarget(-1); return .handled }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.refreshIfStale()
        }
    }

    @ViewBuilder private func controls(_ state: DeviceState, _ caps: Capabilities) -> some View {
        TemperatureCard(state: state, capabilities: caps)

        // Controls that only make sense while the AC is on
        VStack(spacing: 16) {
            if caps.supports(.mode) && !caps.modes.isEmpty {
                ModeSection(state: state, capabilities: caps)
            }
            if caps.supports(.fanSpeed) && !caps.fanSpeeds.isEmpty {
                FanSection(state: state, capabilities: caps)
            }
            if LouverSection.isVisible(caps) {
                LouverSection(state: state, capabilities: caps)
            }
            if TogglesSection.isVisible(caps) {
                TogglesSection(state: state, capabilities: caps)
            }
        }
        .disabled(!state.power)
        .opacity(state.power ? 1 : 0.4)

        // Self-clean usually runs with the AC off
        if caps.supports(.selfClean) {
            SelfCleanSection(state: state)
        }
    }
}
