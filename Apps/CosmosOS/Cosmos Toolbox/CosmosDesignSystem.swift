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

    static let animationFast: Double = 0.18
    static let animationNormal: Double = 0.34
    static let animationSlow: Double = 0.45

    static let pageDuration = 0.38
    static let successDuration = 3.0
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let surfaceRadius: CGFloat = 14
    static func pageAnimation(reduced: Bool) -> Animation? {
        reduced ? nil : .smooth(duration: pageDuration, extraBounce: 0.06)
    }
    static func pageTransition(reduced: Bool) -> AnyTransition {
        .opacity
    }
    /// Yield to the shell without imposing a fixed delay on local reads.
    static func beginPageLoad(reduced: Bool) async -> Bool {
        await Task.yield()
        return !Task.isCancelled
    }

    // MARK: - Card

    static let cardMinHeight: CGFloat = 170
    static let cardPadding: CGFloat = 22

    // MARK: - Window

    static let contentMaxWidth: CGFloat = 2200
}


// MARK: - Cosmos Card Style

struct CosmosCardStyle: ViewModifier {
    let isHovering: Bool
    func body(content: Content) -> some View {
        content.padding(CosmosDesign.cardPadding)
            .background(CosmosDesign.surface, in: RoundedRectangle(cornerRadius: CosmosDesign.surfaceRadius))
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
            .background(CosmosDesign.surface)
            .clipShape(Capsule())
    }
}
