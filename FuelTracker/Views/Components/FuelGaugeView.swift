import SwiftUI

/// Interactive horizontal fuel gauge.
///
/// Displays a coloured bar from E → F. The user drags or taps to set the
/// current fuel level, which snaps to one of nine positions:
/// 0, 1/8, 1/4, 3/8, 1/2, 5/8, 3/4, 7/8, 1
///
/// `level` is a binding in the range [0, 1].
struct FuelGaugeView: View {
    @Binding var level: Double

    private let snapPositions: [Double] = [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]

    private var fillLitres: Double {
        Config.hondaCivicTankLitres * (1.0 - level)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Labels row
            HStack {
                Text("E")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(level < 0.15 ? .red : .secondary)
                Spacer()
                Text("F")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(level > 0.85 ? Color("PinGreen") : .secondary)
            }

            // Gauge bar
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.systemFill))
                        .frame(height: 28)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 8)
                        .fill(gaugeGradient)
                        .frame(width: max(28, width * level), height: 28)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: level)

                    // Thumb
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                        .shadow(radius: 2)
                        .frame(width: 28, height: 28)
                        .offset(x: max(0, min(width - 28, width * level - 14)))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: level)

                    // Invisible drag surface spanning full width
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: 44)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    let raw = drag.location.x / width
                                    level = snap(raw)
                                }
                        )
                }
            }
            .frame(height: 28)

            // Tick marks
            HStack(spacing: 0) {
                ForEach(snapPositions, id: \.self) { pos in
                    if pos > 0 { Spacer() }
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 1, height: 6)
                }
            }

            // Fill-up info
            HStack {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(fillLitres < 1
                     ? "Tank full"
                     : "~\(Int(fillLitres.rounded())) litres to fill up")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text(levelLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(levelColor)
            }
        }
    }

    // MARK: - Helpers

    private func snap(_ raw: Double) -> Double {
        let clamped = max(0, min(1, raw))
        return snapPositions.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? clamped
    }

    private var levelLabel: String {
        switch level {
        case 0:       return "Empty"
        case 0.125:   return "⅛"
        case 0.25:    return "¼"
        case 0.375:   return "⅜"
        case 0.5:     return "½"
        case 0.625:   return "⅝"
        case 0.75:    return "¾"
        case 0.875:   return "⅞"
        case 1:       return "Full"
        default:      return String(format: "%.0f%%", level * 100)
        }
    }

    private var levelColor: Color {
        if level <= 0.125 { return .red }
        if level <= 0.25  { return .orange }
        return Color("PinGreen")
    }

    private var gaugeGradient: LinearGradient {
        LinearGradient(
            colors: [.red, .orange, .yellow, Color("PinGreen")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    VStack(spacing: 32) {
        FuelGaugeView(level: .constant(0.5))
        FuelGaugeView(level: .constant(0.125))
        FuelGaugeView(level: .constant(1.0))
    }
    .padding()
    .preferredColorScheme(.dark)
}
