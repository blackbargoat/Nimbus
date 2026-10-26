import SwiftUI

enum Theme {
    static let sky = Color(red: 0.32, green: 0.66, blue: 0.98)
    static let skyDeep = Color(red: 0.13, green: 0.46, blue: 0.91)
    static let skyMist = Color(red: 0.90, green: 0.95, blue: 1.0)
    static let ink = Color(red: 0.07, green: 0.13, blue: 0.24)
    static let inkSoft = Color(red: 0.24, green: 0.33, blue: 0.47)
    static let sun = Color(red: 1.0, green: 0.72, blue: 0.30)

    /// Bright daytime sky: saturated blue at the top fading to almost white.
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.44, green: 0.66, blue: 0.95), Color(red: 0.66, green: 0.81, blue: 0.98),
                 Color(red: 0.88, green: 0.94, blue: 1.0), Color(red: 0.96, green: 0.98, blue: 1.0)],
        startPoint: .top, endPoint: .bottom
    )
}

/// A frosted card used for every block of notes.
struct GlassCard<Content: View>: View {
    var tint: Color = .white
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(tint == .white ? Color.white.opacity(0.6) : tint.opacity(0.22)),
                         in: .rect(cornerRadius: 22))
    }
}

struct CardTitle: View {
    var symbol: String
    var text: String
    var color: Color = Theme.skyDeep

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}
