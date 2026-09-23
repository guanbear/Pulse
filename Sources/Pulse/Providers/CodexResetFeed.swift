import Foundation

/// A public announcement about Codex limits. This is deliberately separate
/// from `CodexAccountUsage`: an announcement is not evidence that a reset
/// credit has reached this account, and can never replace the limits Pulse
/// reads from Codex itself.
struct CodexResetEvent: Decodable, Equatable, Identifiable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case directReset = "direct_reset"
        case resetCredit = "reset_credit"
    }

    enum Status: String, Decodable, Sendable {
        case announced
        case confirmed
    }

    struct Schedule: Decodable, Equatable, Sendable {
        enum Precision: String, Decodable, Sendable {
            case exact, approximate, deadline, date, window
        }

        let precision: Precision
        let from: Date
        let through: Date
        let label: String
    }

    struct Post: Decodable, Equatable, Sendable {
        let publishedAt: Date
        let text: String
        let originalText: String?
        let url: URL
    }

    let id: String
    let kind: Kind
    let status: Status
    let title: String
    let scope: String
    let createdAt: Date
    let updatedAt: Date
    let confirmedAt: Date?
    let schedule: Schedule?
    let posts: [Post]
    let url: URL

    private enum CodingKeys: String, CodingKey {
        case id, status, title, scope, createdAt, updatedAt, confirmedAt, schedule, posts, url
        case kind = "type"
    }

    /// Old unconfirmed announcements must not remain on the ring for ever.
    /// Scheduled ones remain useful through the announced window and for one
    /// day while confirmation can arrive; schedule-less news gets 48 hours.
    func isDisplayable(at now: Date) -> Bool {
        switch status {
        case .confirmed:
            return now.timeIntervalSince(confirmedAt ?? updatedAt) <= 24 * 60 * 60
        case .announced:
            if let schedule { return now <= schedule.through.addingTimeInterval(24 * 60 * 60) }
            return now.timeIntervalSince(updatedAt) <= 48 * 60 * 60
        }
    }

    /// A recent confirmation outranks an overlapping prediction. Otherwise,
    /// prefer an active window, then the nearest upcoming one. The API is a
    /// correction-capable snapshot, so its array order is not a durable contract.
    static func current(in events: [Self], at now: Date = Date()) -> Self? {
        events
            .filter { $0.isDisplayable(at: now) }
            .sorted { lhs, rhs in
                let left = lhs.selectionRank(at: now)
                let right = rhs.selectionRank(at: now)
                return left.phase == right.phase ? left.order > right.order : left.phase > right.phase
            }
            .first
    }

    /// A confirmed credit can be a separate API event from an earlier reset
    /// announcement. Show the newer fact while it remains displayable rather
    /// than leaving the prediction on screen for the rest of its window.
    private func selectionRank(at now: Date) -> (phase: Int, order: TimeInterval) {
        guard status == .announced else {
            return (6, (confirmedAt ?? updatedAt).timeIntervalSinceReferenceDate)
        }
        guard let schedule else { return (3, updatedAt.timeIntervalSinceReferenceDate) }
        if now < schedule.from { return (4, -schedule.from.timeIntervalSinceReferenceDate) }
        if now <= schedule.through { return (5, schedule.through.timeIntervalSinceReferenceDate) }
        return (3, schedule.through.timeIntervalSinceReferenceDate)
    }
}

struct CodexResetSnapshot: Decodable, Sendable {
    let events: [CodexResetEvent]
}

/// Fetches the small public snapshot at most once every fifteen minutes.
/// Errors retain the last good answer: this auxiliary feed never blanks or
/// delays the provider usage that Pulse exists to show.
actor CodexResetFeed {
    static let shared = CodexResetFeed()
    static let interval: TimeInterval = 15 * 60
    static let source = URL(string: "https://aihot.news/api/v1/codex-resets")!

    private var lastChecked: Date?
    private var nextAllowedAt: Date?
    private var etag: String?
    private var events: [CodexResetEvent] = []
    private var isFetching = false

    func current(force: Bool = false, now: Date = Date()) async -> CodexResetEvent? {
        if !force, let lastChecked, now.timeIntervalSince(lastChecked) < Self.interval {
            return CodexResetEvent.current(in: events, at: now)
        }
        if let nextAllowedAt, now < nextAllowedAt {
            return CodexResetEvent.current(in: events, at: now)
        }
        guard !isFetching else { return CodexResetEvent.current(in: events, at: now) }

        lastChecked = now
        isFetching = true
        defer { isFetching = false }
        var request = URLRequest(url: Self.source)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }

        do {
            let (data, response) = try await NetworkSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return CodexResetEvent.current(in: events, at: now)
            }
            if response.statusCode == 304 {
                return CodexResetEvent.current(in: events, at: now)
            }
            if response.statusCode == 429 {
                nextAllowedAt = Self.retryDate(from: response, now: now)
                return CodexResetEvent.current(in: events, at: now)
            }
            guard (200..<300).contains(response.statusCode) else {
                return CodexResetEvent.current(in: events, at: now)
            }

            let snapshot = try Self.decode(data)
            events = snapshot.events
            etag = response.value(forHTTPHeaderField: "ETag")
            nextAllowedAt = nil
        } catch {
            // The last good snapshot is intentionally kept.
        }

        return CodexResetEvent.current(in: events, at: now)
    }

    static func decode(_ data: Data) throws -> CodexResetSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date: \(value)"
                )
            }
            return date
        }
        return try decoder.decode(CodexResetSnapshot.self, from: data)
    }

    private static func retryDate(from response: HTTPURLResponse, now: Date) -> Date {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else {
            return now.addingTimeInterval(interval)
        }
        if let seconds = TimeInterval(value) { return now.addingTimeInterval(seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        return formatter.date(from: value) ?? now.addingTimeInterval(interval)
    }

}
