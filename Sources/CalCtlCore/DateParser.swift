import Foundation

public enum CalCtlError: Error, CustomStringConvertible, Equatable {
    case invalidDate(String)
    case validation(String)
    case unsafe(String)

    public var description: String {
        switch self {
        case .invalidDate(let message), .validation(let message), .unsafe(let message): return message
        }
    }
}

public struct AllDayDateRange: Equatable {
    public let startDate: Date
    public let endDate: Date
    public let startDateOnly: String
    public let endDateOnly: String
    public let endDateSemantics: String
}

public struct DateParser {
    private static let isoWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    public static func parseTimed(_ raw: String) throws -> Date {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.contains("T") else {
            throw CalCtlError.invalidDate("Timed dates must be ISO 8601 timestamps with timezone, e.g. 2026-05-08T09:00:00-04:00")
        }
        guard hasExplicitTimezone(value) else {
            throw CalCtlError.invalidDate("Timed dates must include an explicit timezone: use Z or ±HH:MM")
        }
        if let date = isoWithFractional.date(from: value) ?? isoNoFractional.date(from: value) {
            return date
        }
        throw CalCtlError.invalidDate("Invalid ISO 8601 timestamp: \(raw)")
    }

    public static func parseAllDayDate(_ raw: String) throws -> DateComponents {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            throw CalCtlError.invalidDate("All-day dates must use YYYY-MM-DD with no time component")
        }
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw CalCtlError.invalidDate("Invalid all-day date: \(raw)") }
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.timeZone = TimeZone.current
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        guard comps.isValidDate else { throw CalCtlError.invalidDate("Invalid all-day date: \(raw)") }
        return comps
    }

    public static func allDayRange(_ raw: String, timeZone: TimeZone = .current) throws -> AllDayDateRange {
        let comps = try parseAllDayDate(raw)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var startComponents = DateComponents()
        startComponents.calendar = calendar
        startComponents.timeZone = timeZone
        startComponents.year = comps.year
        startComponents.month = comps.month
        startComponents.day = comps.day

        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            throw CalCtlError.invalidDate("Could not build all-day date")
        }

        return AllDayDateRange(
            startDate: startDate,
            endDate: endDate,
            startDateOnly: dateOnlyString(from: startDate, calendar: calendar),
            endDateOnly: dateOnlyString(from: endDate, calendar: calendar),
            endDateSemantics: "exclusive"
        )
    }

    private static func hasExplicitTimezone(_ value: String) -> Bool {
        if value.hasSuffix("Z") { return true }
        return value.range(of: #"[+-]\d{2}:?\d{2}$"#, options: .regularExpression) != nil
    }

    public static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    public static func allDayExclusiveEndDateOnly(from eventKitEndDate: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute, .second], from: eventKitEndDate)
        if components.hour == 23, components.minute == 59, (components.second ?? 0) >= 58,
           let exclusiveEnd = calendar.date(byAdding: .second, value: 1, to: eventKitEndDate) {
            return dateOnlyString(from: exclusiveEnd, calendar: calendar)
        }
        return dateOnlyString(from: eventKitEndDate, calendar: calendar)
    }

    private static func dateOnlyString(from date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
