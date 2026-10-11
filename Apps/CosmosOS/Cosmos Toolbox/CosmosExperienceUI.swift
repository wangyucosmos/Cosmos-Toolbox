import SwiftUI
import AppKit

nonisolated enum CosmosDate {
    static var dateTime: Date.FormatStyle { .dateTime.year().month().day().hour().minute().locale(Locale(identifier: "zh_Hans_CN")) }
    static func day(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(calendar.component(.year, from: date) == calendar.component(.year, from: now) ? "MMMd" : "yyyyMMMd")
        return formatter.string(from: date)
    }
    static func greetingDay(_ date: Date, calendar: Calendar = .current) -> String {
        day(date, now: date, calendar: calendar) + " " + date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_Hans_CN")))
    }
    static func timestamp(_ date: Date) -> String {
        day(date) + " " + date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "zh_Hans_CN")))
    }
}

nonisolated enum CosmosAdaptiveLayout {
    static func columns(width: CGFloat, minimum: CGFloat = 180, maximum: Int = 7) -> Int {
        max(1, min(maximum, Int((max(0, width) + 12) / (minimum + 12))))
    }
}

nonisolated enum CosmosIconPalette {
    static func index(_ identity: String) -> Int {
        Int(identity.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 } % 6)
    }
    static func letter(_ name: String) -> String { String(name.prefix(1)) }
}
struct CosmosSquareIcon: View {
    var letter: String? = nil
    var symbol: String? = nil
    var identity: String
    var subdued = false
    var filled = true
    private var color: Color {
        if !filled {
            switch symbol {
            case "exclamationmark.triangle": return .orange
            case "shippingbox": return .green
            case "graduationcap": return .purple
            case "calendar": return .teal
            case "note.text", "text.book.closed": return .indigo
            default: return .blue
            }
        }
        return [.blue, .teal, .indigo, .orange, .purple, .green][CosmosIconPalette.index(identity)]
    }
    var body: some View {
        Group {
            if let letter { Text(letter).font(.system(.body, weight: .semibold)) }
            else { Image(systemName: symbol ?? "square").font(.system(size: 17, weight: .medium)) }
        }.foregroundStyle(filled ? Color.white : color)
            .frame(width: 32, height: 32)
            .background(filled ? color.opacity(0.85) : color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .opacity(subdued ? 0.45 : 1)
            .accessibilityHidden(true)
    }
}
struct CosmosLoadingSkeleton: View {
    var title = "正在读取本地数据…"
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: "clock").font(.callout).foregroundStyle(.secondary)
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(height: index == 0 ? 44 : 78)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel(title)
    }
}
struct CosmosMainWindowPolicy: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowView() }
    func updateNSView(_ nsView: NSView, context: Context) { nsView.window?.titleVisibility = .hidden }
    private final class WindowView: NSView {
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.titleVisibility = .hidden }
    }
}
