import Foundation

// Foreground time only. No website data or account identifiers are stored.
@MainActor
final class UsageTracker {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var checkpoint: Date?
    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults; self.calendar = calendar
    }
    func dayStart(for date: Date) -> Date {
        let midnight = calendar.startOfDay(for: date)
        let reset = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: midnight)!
        if date >= reset { return reset }
        let previous = calendar.date(byAdding: .day, value: -1, to: midnight)!
        return calendar.date(bySettingHour: 3, minute: 0, second: 0, of: previous)!
    }
    func seconds(at date: Date = Date()) -> TimeInterval {
        defaults.double(forKey: "usage.day") == dayStart(for: date).timeIntervalSince1970
            ? defaults.double(forKey: "usage.seconds") : 0
    }
    func begin(at date: Date = Date()) { if checkpoint == nil { checkpoint = date }; record(at: date) }
    func record(at date: Date = Date()) {
        let start = dayStart(for: date)
        let previousSeconds = seconds(at: date)
        let delta = checkpoint.map { max(0, date.timeIntervalSince(max($0, start))) } ?? 0
        defaults.set(start.timeIntervalSince1970, forKey: "usage.day")
        defaults.set(previousSeconds + delta, forKey: "usage.seconds")
        if checkpoint != nil { checkpoint = date }
    }
    func end(at date: Date = Date()) { record(at: date); checkpoint = nil }
    func label(at date: Date = Date()) -> String {
        let minutes = Int(seconds(at: date) / 60)
        return "\(minutes / 60)h \(minutes % 60)m today · resets at 3 AM"
    }
}
