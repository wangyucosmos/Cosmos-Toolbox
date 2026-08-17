import SwiftUI

enum CosmosDesign {

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 18
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32
    static let pagePadding: CGFloat = 38

    // MARK: - Corner Radius

    static let cornerRadiusSmall: CGFloat = 10
    static let cornerRadiusMedium: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 18

    // MARK: - Animation

    static let animationFast: Double = 0.16
    static let animationNormal: Double = 0.22
    static let animationSlow: Double = 0.32

    // MARK: - Card

    static let cardMinHeight: CGFloat = 170
    static let cardPadding: CGFloat = 22

    // MARK: - Window

    static let contentMaxWidth: CGFloat = 1150
}


// MARK: - Cosmos Card Style

struct CosmosCardStyle: ViewModifier {

    let isHovering: Bool

    func body(content: Content) -> some View {
        content
            .padding(CosmosDesign.cardPadding)
            .background(.thinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: CosmosDesign.cornerRadiusLarge,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: CosmosDesign.cornerRadiusLarge,
                    style: .continuous
                )
                .stroke(
                    isHovering
                    ? Color.accentColor.opacity(0.22)
                    : Color.primary.opacity(0.065),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(
                    isHovering ? 0.075 : 0.022
                ),
                radius: isHovering ? 15 : 6,
                y: isHovering ? 6 : 2
            )
            .scaleEffect(
                isHovering ? 1.01 : 1
            )
            .offset(
                y: isHovering ? -2 : 0
            )
            .animation(
                .easeOut(
                    duration: CosmosDesign.animationFast
                ),
                value: isHovering
            )
    }
}


// MARK: - Section Title

struct CosmosSectionTitle: View {

    let title: String
    let subtitle: String

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: CosmosDesign.spacingXS
        ) {

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}


// MARK: - Status Badge

struct CosmosStatusBadge: View {

    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
    }
}
