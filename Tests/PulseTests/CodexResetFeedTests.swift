import Foundation
import Testing
@testable import Pulse

struct CodexResetFeedTests {
    @Test @MainActor
    func announcementsAreOnByDefaultAndCanBeDisabled() {
        #expect(AppSettings().showsCodexResetAnnouncements)
        #expect(!AppSettings(showsCodexResetAnnouncements: false).showsCodexResetAnnouncements)
    }

    @Test @MainActor
    func panelAlwaysBudgetsCombinedCard() {
        let flyoutHeight = FloatingPanelController.Layout.maximumFlyoutHeight
        let sideWidth = DetailCardLayout.width + DetailCardLayout.pointerWidth

        #expect(FloatingPanelController.Layout.size(for: .left).width >= sideWidth)
        #expect(FloatingPanelController.Layout.size(for: .right).width >= sideWidth)
        #expect(FloatingPanelController.Layout.size(for: .left).height >= flyoutHeight)
        #expect(FloatingPanelController.Layout.size(for: .right).height >= flyoutHeight)
        #expect(FloatingPanelController.Layout.size(for: .top).width >= DetailCardLayout.width)
        #expect(FloatingPanelController.Layout.size(for: .top).height >= flyoutHeight)
    }

    @Test
    func decodesSnapshotAndPicksUpcomingEvent() throws {
        let snapshot = try CodexResetFeed.decode(Data(Self.fixture.utf8))
        let event = try #require(CodexResetEvent.current(
            in: snapshot.events,
            at: Self.date("2026-09-21T12:00:00.000+08:00")
        ))

        #expect(event.id == "upcoming")
        #expect(event.kind == .resetCredit)
        #expect(event.posts.first?.originalText == "A reset credit is coming Tuesday.")
    }

    @Test
    func staleAnnouncementDoesNotRemainVisible() throws {
        let snapshot = try CodexResetFeed.decode(Data(Self.fixture.utf8))
        let current = CodexResetEvent.current(
            in: snapshot.events,
            at: Self.date("2026-09-26T16:00:00.000+08:00")
        )

        #expect(current == nil)
    }

    @Test
    func recentConfirmationIsTemporary() throws {
        let snapshot = try CodexResetFeed.decode(Data(Self.fixture.utf8))
        let event = try #require(snapshot.events.first { $0.id == "confirmed" })

        #expect(event.isDisplayable(at: Self.date("2026-09-20T20:00:00.000+08:00")))
        #expect(!event.isDisplayable(at: Self.date("2026-09-22T20:00:00.000+08:00")))
    }

    private static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }

    private static let fixture = #"""
    {
      "events": [
        {
          "id": "upcoming",
          "type": "reset_credit",
          "status": "announced",
          "title": "Reset credit announced",
          "scope": "Pro",
          "createdAt": "2026-09-20T00:48:38.000+08:00",
          "updatedAt": "2026-09-20T00:48:38.000+08:00",
          "confirmedAt": null,
          "schedule": {
            "precision": "date",
            "from": "2026-09-22T15:00:00.000+08:00",
            "through": "2026-09-23T15:00:00.000+08:00",
            "label": "September 22-23"
          },
          "posts": [{
            "publishedAt": "2026-09-20T00:48:38.000+08:00",
            "text": "重置卡将在周二到来。",
            "originalText": "A reset credit is coming Tuesday.",
            "url": "https://example.com/upcoming"
          }],
          "url": "https://example.com/resets"
        },
        {
          "id": "confirmed",
          "type": "direct_reset",
          "status": "confirmed",
          "title": "Reset completed",
          "scope": "",
          "createdAt": "2026-09-20T10:00:00.000+08:00",
          "updatedAt": "2026-09-20T10:00:00.000+08:00",
          "confirmedAt": "2026-09-20T10:00:00.000+08:00",
          "schedule": null,
          "posts": [],
          "url": "https://example.com/resets"
        }
      ]
    }
    """#
}
