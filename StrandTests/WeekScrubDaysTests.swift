import XCTest
@testable import Strand

/// Pins the 8c week-scrubber's day math (`LiquidTodayView.weekScrubDays`): the pull-revealed slot's
/// 7-day row must cover exactly the last 7 calendar days ending on the anchor (today's logical day),
/// oldest first, with each column carrying the day-offset the tap selects — the SAME offset space
/// `selectedDayOffset` already uses (0 = today … 6 = six days back). Pure, no view, no live clock.
final class WeekScrubDaysTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let posix = Locale(identifier: "en_US_POSIX")

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testSevenColumnsOldestFirstEndingOnAnchor() {
        // Friday 2026-08-07 as the anchor.
        let days = LiquidTodayView.weekScrubDays(anchor: date(2026, 8, 7), calendar: cal, locale: posix)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map(\.offset), [6, 5, 4, 3, 2, 1, 0])          // oldest → today
        XCTAssertEqual(days.map(\.dayNumber), ["1", "2", "3", "4", "5", "6", "7"])
        XCTAssertEqual(days.first?.weekday, "Sat")                          // 1 Aug 2026
        XCTAssertEqual(days.last?.weekday, "Fri")                           // the anchor itself
    }

    func testCrossesAMonthBoundary() {
        // Anchor Tue 2026-09-01: the row must reach back into August.
        let days = LiquidTodayView.weekScrubDays(anchor: date(2026, 9, 1), calendar: cal, locale: posix)
        XCTAssertEqual(days.map(\.dayNumber), ["26", "27", "28", "29", "30", "31", "1"])
        XCTAssertEqual(days.last?.offset, 0)
        XCTAssertEqual(days.first?.offset, 6)
    }
}
