import SwiftUI

struct VerdictBadge: View {
    let isWorthIt: Bool
    let savingText: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isWorthIt ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
            Text(isWorthIt ? "WORTH IT" : "NOT WORTH IT")
                .font(.system(size: 11, weight: .black))
                .kerning(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isWorthIt ? Color("PinGreen") : Color("PinRed"))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        VerdictBadge(isWorthIt: true,  savingText: "Save £1.20")
        VerdictBadge(isWorthIt: false, savingText: "£0.45 extra")
    }
    .padding()
    .preferredColorScheme(.dark)
}
