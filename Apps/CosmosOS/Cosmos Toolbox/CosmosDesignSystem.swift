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
    static let entranceInterval = 0.032
    static let entranceLimit = 8
    static let successDuration = 3.0
    static func entranceDelay(index: Int, reduced: Bool) -> Double {
        reduced || index >= entranceLimit ? 0 : Double(max(0, index)) * entranceInterval
    }
    static func pageAnimation(reduced: Bool) -> Animation? {
        reduced ? nil : .smooth(duration: pageDuration, extraBounce: 0.06)
    }
    static func pageTransition(reduced: Bool) -> AnyTransition {
        reduced ? .opacity : .opacity.combined(with: .scale(scale: 0.98))
            .combined(with: AnyTransition(.blurReplace)).combined(with: .offset(y: 6))
    }
    /// Wait asynchronously until the shell's transition has started / settled, then use the existing reader.
    static func beginPageLoad(reduced: Bool) async -> Bool {
        do {
            if !reduced { try await Task.sleep(for: .seconds(pageDuration)) }
            else { await Task.yield() }
            return !Task.isCancelled
        } catch { return false }
    }

    // MARK: - Card

    static let cardMinHeight: CGFloat = 170
    static let cardPadding: CGFloat = 22

    // MARK: - Window

    static let contentMaxWidth: CGFloat = 1150
}


// MARK: - Cosmos Card Style

struct CosmosCardStyle: ViewModifier {

    let isHovering: Bool
    @Environment(\.accessibilityReduceMotion) private var systemMotion
    @Environment(\.cosmosPreferences) private var preferences

    func body(content: Content) -> some View {
        content
            .padding(CosmosDesign.cardPadding)
            .background(Color(nsColor: .controlBackgroundColor))
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
                isHovering && !preferences.reducesMotion(system: systemMotion) ? 1.01 : 1
            )
            .offset(
                y: isHovering && !preferences.reducesMotion(system: systemMotion) ? -2 : 0
            )
            .animation(
                preferences.reducesMotion(system: systemMotion) ? nil : .smooth(duration: CosmosDesign.animationFast),
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
