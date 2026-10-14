/// Louver axis: vertical = up/down, horizontal = left/right.
public enum Axis: CaseIterable, Identifiable, Sendable {
    case vertical, horizontal

    public var id: Self { self }
    var label: String { self == .vertical ? "Up/down" : "Left/right" }
    /// Labels for the ends: position 1 and the last position
    var endLabels: (first: String, last: String) { self == .vertical ? ("forward", "floor") : ("left", "right") }
    var symbol: String { self == .vertical ? "arrow.up.and.down" : "arrow.left.and.right" }
    var swingFeature: Feature { self == .vertical ? .swingVertical : .swingHorizontal }
    var louverFeature: Feature { self == .vertical ? .louverVertical : .louverHorizontal }

    func isSwinging(_ s: DeviceState) -> Bool { self == .vertical ? s.swingVertical : s.swingHorizontal }
    func position(_ s: DeviceState) -> Int? { self == .vertical ? s.louverVertical : s.louverHorizontal }

    func swing(_ on: Bool) -> Changes {
        self == .vertical ? Changes(swingVertical: on) : Changes(swingHorizontal: on)
    }

    func fix(at position: Int) -> Changes {
        self == .vertical ? Changes(louverVertical: position) : Changes(louverHorizontal: position)
    }

    /// Angle of the airflow in the diagram, in degrees, for each position (1...n). `nil` = middle position.
    /// Up/down (side view): 0° = forward, 80° = almost to the floor.
    /// Left/right (top view): −45° = left, 0° = straight, +45° = right.
    func airAngle(_ position: Int?, of count: Int) -> Double {
        let t = position.map { count > 1 ? Double($0 - 1) / Double(count - 1) : 0.5 } ?? 0.5
        return self == .vertical ? t * 80 : (t - 0.5) * 90
    }

    /// Range covered while swinging.
    var sweep: ClosedRange<Double> { self == .vertical ? 0...80 : -45...45 }
}
