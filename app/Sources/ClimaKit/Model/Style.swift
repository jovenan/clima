import SwiftUI

/// How each domain value is shown. Unknown values get a generic look.
enum Style {
    struct ModeStyle {
        let label: String
        let symbol: String
        let color: Color
    }

    static let modes: [String: ModeStyle] = [
        "cool": ModeStyle(label: "Cool", symbol: "snowflake", color: Color(red: 0.25, green: 0.62, blue: 1.0)),
        "heat": ModeStyle(label: "Heat", symbol: "flame.fill", color: Color(red: 1.0, green: 0.48, blue: 0.2)),
        "dry": ModeStyle(label: "Dry", symbol: "drop.fill", color: Color(red: 0.2, green: 0.75, blue: 0.75)),
        "fan": ModeStyle(label: "Fan", symbol: "fan.fill", color: Color(red: 0.35, green: 0.78, blue: 0.5)),
        "auto": ModeStyle(label: "Auto", symbol: "arrow.triangle.2.circlepath",
                          color: Color(red: 0.62, green: 0.45, blue: 1.0)),
    ]

    static func mode(_ name: String?) -> ModeStyle {
        modes[name ?? ""] ?? ModeStyle(label: name?.capitalized ?? "—", symbol: "circle", color: .accentColor)
    }

    /// Speeds in increasing order (Auto is handled separately)
    static let fanLevels: [(key: String, label: String)] = [
        ("silent", "Silent"), ("low", "Low"), ("medium", "Medium"), ("high", "High"), ("max", "Max"),
    ]

    static let clean = Color(red: 0.3, green: 0.8, blue: 0.95)

    static func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "en_US")))
    }
}
