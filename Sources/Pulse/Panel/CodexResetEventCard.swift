import SwiftUI

enum ResetEventCardLayout {
    /// Matches the usage card's body. The usage card is wider only by its
    /// pointer, which the stacked event card pads around at the rail side.
    static var width: CGFloat { DetailCardLayout.width }
    static var gap: CGFloat { 12 * PanelMetrics.scale }
    static var maximumHeight: CGFloat { 250 * PanelMetrics.scale }
}

/// A second, adjacent card for public reset news. It never takes the place of
/// `UsageDetailCard`, because an announcement and this account's live quota
/// answer different questions.
struct CodexResetEventCard: View {
    let event: CodexResetEvent
    var usesGlass = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12 * PanelMetrics.scale) {
                HStack(spacing: 8 * PanelMetrics.scale) {
                    Image(systemName: event.kind == .resetCredit ? "ticket" : "arrow.clockwise")
                        .font(.system(size: 14 * PanelMetrics.scale, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(event.kind == .resetCredit
                         ? String.localized("Reset credit")
                         : String.localized("Limit reset"))
                        .font(.system(size: 13 * PanelMetrics.scale, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(event.status == .confirmed
                         ? String.localized("Confirmed")
                         : String.localized("Announced"))
                        .font(.system(size: 10.5 * PanelMetrics.scale, weight: .medium))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4 * PanelMetrics.scale) {
                    Text(event.title)
                        .font(.system(size: 13 * PanelMetrics.scale, weight: .semibold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(timing(at: context.date))
                        .font(.system(size: 12 * PanelMetrics.scale, weight: .medium, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                }

                if let post = event.posts.first {
                    Text(postText(post))
                        .font(.system(size: 11 * PanelMetrics.scale, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 5 * PanelMetrics.scale) {
                    Image(systemName: "link")
                    Text(localized: "AI Hot News · original post")
                }
                .font(.system(size: 10.5 * PanelMetrics.scale, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(DetailCardLayout.padding)
            .frame(width: ResetEventCardLayout.width, alignment: .leading)
            .background(
                PanelSurface(
                    shape: RoundedRectangle(
                        cornerRadius: DetailCardLayout.cornerRadius,
                        style: .continuous
                    ),
                    usesGlass: usesGlass
                )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String.localized("Codex reset announcement"))
        }
    }

    private var accent: Color {
        event.status == .confirmed ? .green : .orange
    }

    private func timing(at now: Date) -> String {
        if event.status == .confirmed {
            return String.localized("Confirmed recently")
        }
        guard let schedule = event.schedule else {
            return String.localized("Time not specified")
        }
        if now < schedule.from {
            return String.localized("Expected \(Self.relative(from: now, to: schedule.from))")
        }
        if now <= schedule.through {
            return schedule.precision == .exact
                ? String.localized("Expected now")
                : String.localized("Expected window is open")
        }
        return String.localized("Awaiting confirmation")
    }

    private func postText(_ post: CodexResetEvent.Post) -> String {
        let language = LocalizationSource.locale.language.languageCode?.identifier ?? "en"
        return language.hasPrefix("zh") ? post.text : (post.originalText ?? post.text)
    }

    private static func relative(from start: Date, to end: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = LocalizationSource.locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: end, relativeTo: start)
    }
}
