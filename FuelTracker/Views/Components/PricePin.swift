import SwiftUI

/// Map annotation bubble showing a station's effective price per litre.
struct PricePin: View {
    let displayPricePence: Double?
    let pinColor: Color
    let isEsso: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                if isEsso {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 8, weight: .bold))
                }
                if let price = displayPricePence {
                    Text(String(format: "%.0fp", price))
                        .font(.system(size: isSelected ? 13 : 11, weight: .black))
                } else {
                    Text("?")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, isSelected ? 8 : 6)
            .padding(.vertical, isSelected ? 5 : 3)
            .background(pinColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.4), radius: isSelected ? 4 : 2, y: 1)

            // Downward-pointing triangle tail
            PinTail(color: pinColor)
                .frame(width: 8, height: 5)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

private struct PinTail: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w / 2, y: h))
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        PricePin(displayPricePence: 138.9, pinColor: Color("PinGreen"), isEsso: false, isSelected: false)
        PricePin(displayPricePence: 145.9, pinColor: Color("PinAmber"), isEsso: false, isSelected: true)
        PricePin(displayPricePence: 152.9, pinColor: Color("PinRed"),   isEsso: false, isSelected: false)
        PricePin(displayPricePence: 148.9, pinColor: .blue,              isEsso: true,  isSelected: false)
    }
    .padding()
    .background(Color.black)
}
