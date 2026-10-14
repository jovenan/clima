import SwiftUI

/// Airflow. For each supported axis: a live diagram (unit + airflow),
/// the "Swing" button (if any) and numbered fixed positions, with labels at the ends.
struct LouverSection: View {
    @EnvironmentObject private var store: ClimateStore
    let state: DeviceState
    let capabilities: Capabilities

    static func isVisible(_ capabilities: Capabilities) -> Bool {
        Axis.allCases.contains { capabilities.supportsAny($0.swingFeature, $0.louverFeature) }
    }

    private var axes: [Axis] {
        Axis.allCases.filter { capabilities.supportsAny($0.swingFeature, $0.louverFeature) }
    }

    var body: some View {
        VStack(spacing: 10) {
            SectionTitle(title: "Airflow")
            ForEach(axes) { axis in row(axis) }
        }
    }

    private func row(_ axis: Axis) -> some View {
        let tint = store.tint
        let swinging = axis.isSwinging(state)
        let position = axis.position(state)
        let count = capabilities.louverPositions

        return HStack(alignment: .top, spacing: 10) {
            AirflowDiagram(axis: axis, angle: axis.airAngle(position, of: count), swinging: swinging,
                           fixed: position != nil, color: tint)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                .help(axis == .vertical ? "Side view: unit on the wall, floor below"
                                        : "Top view: unit on the wall, room below")

            VStack(spacing: 5) {
                HStack {
                    Text(axis.label).font(.system(size: 12, weight: .semibold))
                    Text(status(axis)).font(.system(size: 10)).foregroundStyle(.tertiary)
                    Spacer()
                    if capabilities.supports(axis.swingFeature) {
                        Tile(selected: swinging, color: tint, height: 22) {
                            store.apply(axis.swing(!swinging))
                        } content: {
                            Label("Swing", systemImage: axis.symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .labelStyle(CompactLabel())
                        }
                        .frame(width: 74)
                    }
                }
                .foregroundStyle(.secondary)

                if capabilities.supports(axis.louverFeature) {
                    HStack(spacing: 4) {
                        ForEach(1...max(1, count), id: \.self) { p in
                            Tile(selected: !swinging && position == p, color: tint, height: 22) {
                                store.apply(axis.fix(at: p))
                            } content: {
                                Text("\(p)").font(.system(size: 11, weight: .semibold)).monospacedDigit()
                            }
                            .help("Fix at position \(p)")
                        }
                    }
                    HStack {
                        Text(axis.endLabels.first)
                        Spacer()
                        Text(axis.endLabels.last)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func status(_ axis: Axis) -> String {
        if axis.isSwinging(state) { return "swinging" }
        return axis.position(state).map { "position \($0)" } ?? "stopped"
    }
}
