import Foundation

struct UsageSummary {
    let todaySeconds: TimeInterval
    let lifetimeSeconds: TimeInterval
    let projectedSeconds: TimeInterval

    private func hoursAndMinutes(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        return "\(minutes / 60)h \(minutes % 60)m"
    }
    var todayLabel: String { "Today: \(hoursAndMinutes(todaySeconds))" }
    var lifetimeLabel: String { "Total time spent: \(hoursAndMinutes(lifetimeSeconds))" }
    var projectionLabel: String {
        let minutes = Int(max(0, projectedSeconds) / 60)
        return "Expected time wasted by Dec 31: \(minutes / 1440)d \(minutes / 60 % 24)h \(minutes % 60)m"
    }
}

// Foreground time only. No website data or account identifiers are stored.
@MainActor
final class UsageTracker {
    private struct State: Codable {
        var lifetime: TimeInterval = 0
        var days: [String: TimeInterval] = [:]
    }
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var checkpoint: Date?
    private var state: State
    private let stateKey = "usage.statistics.v1"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.defaults = defaults; self.calendar = calendar
        if let data = defaults.data(forKey: stateKey), let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        } else {
            let seconds = max(0, defaults.double(forKey: "usage.seconds"))
            let day = defaults.double(forKey: "usage.day")
            state = State(lifetime: seconds)
            if defaults.object(forKey: "usage.day") != nil {
                state.days[String(day)] = seconds
            }
            persist()
        }
    }
    func dayStart(for date: Date) -> Date {
        let midnight = calendar.startOfDay(for: date)
        let reset = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: midnight)!
        if date >= reset { return reset }
        let previous = calendar.date(byAdding: .day, value: -1, to: midnight)!
        return calendar.date(bySettingHour: 3, minute: 0, second: 0, of: previous)!
    }
    private func key(for day: Date) -> String { String(day.timeIntervalSince1970) }
    private func nextDay(after day: Date) -> Date {
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        return calendar.date(bySettingHour: 3, minute: 0, second: 0, of: next)!
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: stateKey) }
    }
    func seconds(at date: Date = Date()) -> TimeInterval {
        state.days[key(for: dayStart(for: date))] ?? 0
    }
    func summary(at date: Date = Date()) -> UsageSummary {
        let today = dayStart(for: date)
        let first = calendar.date(byAdding: .day, value: -6, to: today)!
        let maximum = state.days.compactMap { key, seconds -> TimeInterval? in
            guard let timestamp = Double(key), timestamp >= first.timeIntervalSince1970,
                  timestamp <= today.timeIntervalSince1970 else { return nil }
            return seconds
        }.max() ?? 0
        let yearEnd = calendar.dateInterval(of: .year, for: date)!.end
        let projection = maximum * max(0, yearEnd.timeIntervalSince(date)) / 86_400
        return UsageSummary(todaySeconds: seconds(at: date), lifetimeSeconds: state.lifetime, projectedSeconds: projection)
    }
    func begin(at date: Date = Date()) {
        if checkpoint == nil { checkpoint = date }
        record(at: date)
    }
    func record(at date: Date = Date()) {
        if let checkpoint, date > checkpoint {
            state.lifetime += date.timeIntervalSince(checkpoint)
            var cursor = checkpoint
            while cursor < date {
                let day = dayStart(for: cursor)
                let end = min(date, nextDay(after: day))
                state.days[key(for: day), default: 0] += end.timeIntervalSince(cursor)
                cursor = end
            }
        }
        let today = dayStart(for: date)
        let first = calendar.date(byAdding: .day, value: -6, to: today)!.timeIntervalSince1970
        state.days = state.days.filter {
            guard let timestamp = Double($0.key) else { return false }
            return timestamp >= first && timestamp <= today.timeIntervalSince1970
        }
        persist()
        if let previous = checkpoint { checkpoint = max(previous, date) }
    }
    func end(at date: Date = Date()) { record(at: date); checkpoint = nil }
}
