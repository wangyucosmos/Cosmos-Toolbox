import SwiftUI
import AppKit

struct CosmosWorkflowMiniProgress: View {
    let completed: Int
    let total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text("Workflow"); Spacer(); Text(total == 0 ? "尚未开始" : "\(completed) / \(total)") }
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule().fill(total > 0 && index < completed ? Color.accentColor : Color.primary.opacity(0.09)).frame(height: 4)
                }
            }
        }.accessibilityLabel("Workflow 已完成 \(completed) 个，共 \(total) 个启用步骤")
    }
}

struct CosmosWorkCard<Status: View>: View {
    let title: String
    let scope: String
    let dates: String
    let completed: Int
    let total: Int
    let adopted: Int
    let attention: Bool
    var compact = false
    @ViewBuilder var status: Status
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).font(.headline).lineLimit(2)
                        Text(scope).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    status
                }
                Label(dates, systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                CosmosWorkflowMiniProgress(completed: completed, total: total)
                HStack {
                    Label("采用产物 \(adopted)", systemImage: "doc.text").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if attention { Label("需关注", systemImage: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.orange) }
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(CosmosInteractiveCardStyle()).accessibilityLabel(title + "，" + scope + (attention ? "，需关注" : ""))
    }
}

nonisolated enum CosmosWorkspaceSplitWidth {
    static let minimum: CGFloat = 220
    static let maximum: CGFloat = 360
    struct Item {
        let title: String
        var count: Int? = nil
        var attention = false
    }
    @MainActor static func nameFont(scale: CGFloat, selected: Bool = true) -> NSFont {
        NSFont.systemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize * scale, weight: selected ? .semibold : .medium)
    }
    @MainActor static func countFont(scale: CGFloat) -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize * scale, weight: .regular)
    }
    @MainActor static func requiredMinimum(items: [Item], scale: CGFloat) -> CGFloat {
        let scrollbar = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        let widths = items.map { item in
            let name = (item.title as NSString).size(withAttributes: [.font: nameFont(scale: scale)]).width
            let badge = item.count.map { ( $0.formatted() as NSString).size(withAttributes: [.font: countFont(scale: scale)]).width + 14 } ?? 0
            // Icon32, parent24, row20, spacer4, gap10 per neighbouring pair; reserve system scroller.
            let gaps: CGFloat = item.count == nil ? 20 : 30
            return ceil(name + 32 + 24 + 20 + 4 + gaps + badge + (item.attention ? 16 : 0) + scrollbar + 8)
        }
        return max(minimum, widths.max() ?? minimum)
    }
    static func displayed(_ saved: Double, minimum: CGFloat) -> CGFloat {
        max(minimum, min(max(maximum, minimum), CGFloat(saved.isFinite ? saved : 260)))
    }
    static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(Double(maximum), max(Double(minimum), value)) : 260
    }
}

/// Observe the existing native split without replacing SwiftUI's delegate or child hosts.
struct CosmosNativeSplitWidth: NSViewRepresentable {
    @Binding var width: Double
    func makeNSView(context: Context) -> Probe { Probe(width: $width) }
    func updateNSView(_ view: Probe, context: Context) { view.width = $width }
    final class Probe: NSView {
        var width: Binding<Double>
        private weak var split: NSSplitView?
        init(width: Binding<Double>) { self.width = width; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { NotificationCenter.default.removeObserver(self); split = nil; return }
            DispatchQueue.main.async { [weak self] in self?.attach() }
        }
        private func attach() {
            var parent = superview
            while let current = parent {
                if let candidate = current as? NSSplitView {
                    guard split !== candidate else { return }
                    NotificationCenter.default.removeObserver(self)
                    split = candidate; candidate.dividerStyle = .thin
                    candidate.setPosition(CGFloat(width.wrappedValue), ofDividerAt: 0)
                    NotificationCenter.default.addObserver(self, selector: #selector(resized), name: NSSplitView.didResizeSubviewsNotification, object: candidate)
                    return
                }
                parent = current.superview
            }
        }
        @objc private func resized() {
            guard let split, let sidebar = split.subviews.first, sidebar.frame.width > 0 else { return }
            let value = CosmosWorkspaceSplitWidth.clamp(Double(sidebar.frame.width))
            guard abs(value - width.wrappedValue) > 0.5 else { return }
            // Leave AppKit's resize transaction before publishing the UI preference.
            DispatchQueue.main.async { [weak self] in self?.width.wrappedValue = value }
        }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
