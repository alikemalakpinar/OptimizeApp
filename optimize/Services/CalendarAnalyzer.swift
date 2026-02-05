//
//  CalendarAnalyzer.swift
//  optimize
//
//  Analyzes the user's calendar to find cleanup opportunities.
//  Uses EventKit to detect:
//  - Old past events (older than 6 months)
//  - Spam/subscribed calendars (common spam patterns)
//
//  PRIVACY: Only reads event metadata - never modifies without user action.
//

import EventKit
import Foundation

// MARK: - Calendar Cleanup Models

struct CalendarCleanupItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let date: Date?
    let calendarTitle: String?
    let eventIdentifier: String?
    let calendarIdentifier: String?
    let type: CalendarIssueType
}

enum CalendarIssueType {
    case oldEvent
    case spamCalendar
}

struct CalendarAnalysisResult {
    let oldEvents: [CalendarCleanupItem]
    let spamCalendars: [CalendarCleanupItem]
    let totalEventCount: Int

    var totalIssueCount: Int {
        oldEvents.count + spamCalendars.count
    }

    static let empty = CalendarAnalysisResult(
        oldEvents: [],
        spamCalendars: [],
        totalEventCount: 0
    )
}

// MARK: - Calendar Analyzer

@MainActor
final class CalendarAnalyzer: ObservableObject {

    @Published var state: AnalysisState = .idle
    @Published var progress: Double = 0

    enum AnalysisState: Equatable {
        case idle
        case analyzing
        case completed(CalendarAnalysisResult)
        case permissionDenied
        case error(String)

        static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.analyzing, .analyzing), (.permissionDenied, .permissionDenied):
                return true
            case (.completed(let a), .completed(let b)):
                return a.totalIssueCount == b.totalIssueCount
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private let eventStore = EKEventStore()

    // Common spam calendar keywords
    private let spamKeywords = [
        "click here", "free", "winner", "congratulations", "prize",
        "casino", "lottery", "bitcoin", "crypto", "discount",
        "tıkla", "bedava", "kazandınız", "ödül", "kazan",
        "viagra", "weight loss", "dating", "subscribe"
    ]

    // MARK: - Public API

    func analyze() async {
        state = .analyzing
        progress = 0

        // Request access
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }

            guard granted else {
                state = .permissionDenied
                return
            }
        } catch {
            state = .permissionDenied
            return
        }

        progress = 0.2

        // Find old events (> 6 months ago)
        let oldEvents = findOldEvents()
        progress = 0.6

        // Find spam calendars
        let spamCalendars = findSpamCalendars()
        progress = 0.9

        // Count total events
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let now = Date()
        let predicate = eventStore.predicateForEvents(withStart: sixMonthsAgo, end: now, calendars: nil)
        let totalCount = eventStore.events(matching: predicate).count

        progress = 1.0

        let result = CalendarAnalysisResult(
            oldEvents: oldEvents,
            spamCalendars: spamCalendars,
            totalEventCount: totalCount
        )

        state = .completed(result)
    }

    /// Delete old events
    func deleteEvents(_ items: [CalendarCleanupItem]) -> Int {
        var deletedCount = 0
        for item in items {
            guard let eventId = item.eventIdentifier,
                  let event = eventStore.event(withIdentifier: eventId) else { continue }
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
                deletedCount += 1
            } catch {
                continue
            }
        }
        // Commit all at once
        if deletedCount > 0 {
            try? eventStore.commit()
        }
        return deletedCount
    }

    /// Remove a subscribed/spam calendar entirely
    func removeCalendar(_ item: CalendarCleanupItem) -> Bool {
        guard let calId = item.calendarIdentifier,
              let calendar = eventStore.calendar(withIdentifier: calId) else { return false }
        do {
            try eventStore.removeCalendar(calendar, commit: true)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Analysis Logic

    private func findOldEvents() -> [CalendarCleanupItem] {
        // Events older than 6 months
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: twoYearsAgo, end: sixMonthsAgo, calendars: nil)
        let events = eventStore.events(matching: predicate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "tr_TR")

        return events.prefix(200).map { event in
            CalendarCleanupItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "İsimsiz Etkinlik",
                detail: dateFormatter.string(from: event.startDate),
                date: event.startDate,
                calendarTitle: event.calendar?.title,
                eventIdentifier: event.eventIdentifier,
                calendarIdentifier: nil,
                type: .oldEvent
            )
        }
    }

    private func findSpamCalendars() -> [CalendarCleanupItem] {
        let calendars = eventStore.calendars(for: .event)
        var spamItems: [CalendarCleanupItem] = []

        for calendar in calendars {
            // Only check subscribed calendars (not local/iCloud ones the user created)
            guard calendar.type == .subscription || calendar.type == .calDAV else { continue }

            let titleLower = calendar.title.lowercased()
            let isSpam = spamKeywords.contains { titleLower.contains($0) }

            if isSpam {
                // Count events in this calendar
                let start = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
                let end = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [calendar])
                let eventCount = eventStore.events(matching: predicate).count

                spamItems.append(CalendarCleanupItem(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    detail: "\(eventCount) etkinlik",
                    date: nil,
                    calendarTitle: calendar.title,
                    eventIdentifier: nil,
                    calendarIdentifier: calendar.calendarIdentifier,
                    type: .spamCalendar
                ))
            }
        }

        return spamItems
    }
}
