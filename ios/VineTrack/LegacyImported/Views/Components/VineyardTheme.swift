import SwiftUI

enum VineyardTheme {
    static let leafGreen = Color(red: 0.36, green: 0.55, blue: 0.30)
    static let olive = Color(red: 0.45, green: 0.50, blue: 0.25)
    static let earthBrown = Color(red: 0.45, green: 0.32, blue: 0.22)
    static let vineRed = Color(red: 0.55, green: 0.18, blue: 0.22)
    static let cream = Color(red: 0.97, green: 0.95, blue: 0.88)
    static let stone = Color(red: 0.78, green: 0.74, blue: 0.66)
}

struct GrapeLeafIcon: View {
    var size: CGFloat = 14
    var color: Color = VineyardTheme.olive

    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
    }
}
