import SwiftUI

enum ResetEventCardLayout {
    /// The section has no outer padding or surface of its own; both belong to
    /// the usage bubble that contains it. This is only the conservative space
    /// the fixed AppKit panel reserves for its variable text.
    static var maximumHeight: CGFloat { 250 * PanelMetrics.scale }
}

/// Public reset news inside the Codex usage bubble. The divider supplied by
/// `UsageDetailCard` keeps this third-party announcement distinct from the
/// provider-reported quota without making it look like a detached popover.
struct CodexResetEventSection: View {
    let event: CodexResetEvent

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

                Link(destination: event.posts.first?.url ?? event.url) {
                    HStack(spacing: 5 * PanelMetrics.scale) {
                        Image(systemName: "link")
                        Text(localized: "AI Hot News · original post")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5 * PanelMetrics.scale, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .contain)
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
