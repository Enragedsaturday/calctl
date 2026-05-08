import Foundation

public struct EventDraft: Equatable {
    public let title: String
    public let start: Date
    public let end: Date

    public static func validateTimed(title: String, start: Date, end: Date) throws -> EventDraft {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw CalCtlError.validation("Event title cannot be blank") }
        guard end > start else { throw CalCtlError.validation("Event end must be after start") }
        return EventDraft(title: cleaned, start: start, end: end)
    }
}

public struct CreateEventPreflight: Equatable {
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let startDateOnly: String?
    public let endDateOnly: String?
    public let endDateSemantics: String?
    public let url: URL?
    public let alarmMinutes: [Int]
}

public struct UpdateEventPreflight: Equatable {
    public let title: String?
    public let startDate: Date?
    public let endDate: Date?
    public let span: EventSpan
}

public struct Safety {
    public static func requireForce(_ force: Bool, action: String) throws {
        guard force else {
            throw CalCtlError.unsafe("Refusing to \(action) without --force. First run the matching show/list command and confirm the exact item.")
        }
    }

    public static func requireNotBoth(_ hasFirst: Bool, _ first: String, _ hasSecond: Bool, _ second: String) throws {
        if hasFirst && hasSecond {
            throw CalCtlError.validation("Use either \(first) or \(second), not both")
        }
    }

    public static func parseURL(_ raw: String) throws -> URL {
        guard let url = URL(string: raw), let scheme = url.scheme, !scheme.isEmpty else {
            throw CalCtlError.validation("Invalid URL: \(raw)")
        }
        return url
    }
}

public struct EventOutputPolicy {
    /// Mutation responses omit notes by default to avoid echoing sensitive event bodies.
    public static let mutationIncludeNotesByDefault = false
}

public struct AlertDefaults {
    public static let standardMinutes = [1440, 120]
    public static let maxMinutes = 60 * 24 * 365

    public static func validate(_ minutes: [Int]) throws -> [Int] {
        for value in minutes {
            guard value >= 0 && value <= maxMinutes else {
                throw CalCtlError.validation("Alarm minutes must be between 0 and 525600")
            }
        }
        return unique(minutes)
    }

    public static func unique(_ minutes: [Int]) -> [Int] {
        var seen = Set<Int>()
        var result: [Int] = []
        for value in minutes where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    public static func merge(defaults: [Int], explicit: [Int], includeDefaults: Bool) throws -> [Int] {
        let validDefaults = try validate(defaults)
        let validExplicit = try validate(explicit)
        return unique((includeDefaults ? validDefaults : []) + validExplicit)
    }
}

public struct StructuredLocationInput: Equatable {
    public let title: String?
    public let latitude: Double?
    public let longitude: Double?
    public let radiusMeters: Double?

    public static func validate(title: String?, latitude: Double?, longitude: Double?, radiusMeters: Double?) throws -> StructuredLocationInput? {
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTitle = cleanTitle?.isEmpty == false
        let hasLatitude = latitude != nil
        let hasLongitude = longitude != nil
        let hasRadius = radiusMeters != nil

        if title != nil && !hasTitle {
            throw CalCtlError.validation("--structured-location-title cannot be blank")
        }
        guard hasTitle || hasLatitude || hasLongitude || hasRadius else { return nil }
        guard hasLatitude == hasLongitude else {
            throw CalCtlError.validation("--latitude and --longitude must be supplied together")
        }
        if let latitude {
            guard latitude.isFinite && latitude >= -90 && latitude <= 90 else {
                throw CalCtlError.validation("--latitude must be between -90 and 90")
            }
        }
        if let longitude {
            guard longitude.isFinite && longitude >= -180 && longitude <= 180 else {
                throw CalCtlError.validation("--longitude must be between -180 and 180")
            }
        }
        if let radiusMeters {
            guard radiusMeters.isFinite && radiusMeters >= 0 else {
                throw CalCtlError.validation("--radius-meters must be a non-negative number")
            }
            guard hasLatitude else {
                throw CalCtlError.validation("--radius-meters requires --latitude and --longitude")
            }
        }

        return StructuredLocationInput(title: cleanTitle, latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)
    }
}

public struct EventPreflight {
    public static let maxAlarmMinutes = AlertDefaults.maxMinutes

    public static func validateCreate(
        title: String,
        start: String?,
        end: String?,
        allDayDate: String?,
        url: String?,
        alarmMinutes: [Int]
    ) throws -> CreateEventPreflight {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { throw CalCtlError.validation("Event title cannot be blank") }

        let parsedURL = try url.map { try Safety.parseURL($0) }
        _ = try AlertDefaults.validate(alarmMinutes)

        if let allDayDate {
            guard start == nil && end == nil else {
                throw CalCtlError.validation("Use either --date or --start/--end, not both")
            }
            let range = try DateParser.allDayRange(allDayDate)
            return CreateEventPreflight(
                title: cleanedTitle,
                startDate: range.startDate,
                endDate: range.endDate,
                isAllDay: true,
                startDateOnly: range.startDateOnly,
                endDateOnly: range.endDateOnly,
                endDateSemantics: range.endDateSemantics,
                url: parsedURL,
                alarmMinutes: alarmMinutes
            )
        }

        guard let start, let end else {
            throw CalCtlError.validation("Timed events require both --start and --end; all-day events require --date")
        }
        let startDate = try DateParser.parseTimed(start)
        let endDate = try DateParser.parseTimed(end)
        let draft = try EventDraft.validateTimed(title: cleanedTitle, start: startDate, end: endDate)
        return CreateEventPreflight(
            title: draft.title,
            startDate: draft.start,
            endDate: draft.end,
            isAllDay: false,
            startDateOnly: nil,
            endDateOnly: nil,
            endDateSemantics: nil,
            url: parsedURL,
            alarmMinutes: alarmMinutes
        )
    }

    public static func validateUpdate(
        title: String?,
        start: String?,
        end: String?,
        location: String?,
        clearLocation: Bool,
        notes: String?,
        clearNotes: Bool,
        span: String
    ) throws -> UpdateEventPreflight {
        let parsedSpan = try validateSpan(span)
        try Safety.requireNotBoth(clearLocation, "--clear-location", location != nil, "--location")
        try Safety.requireNotBoth(clearNotes, "--clear-notes", notes != nil, "--notes")

        var cleanedTitle: String?
        var startDate: Date?
        var endDate: Date?
        var changed = false

        if let title {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { throw CalCtlError.validation("Event title cannot be blank") }
            cleanedTitle = clean
            changed = true
        }

        if start != nil || end != nil {
            guard let start, let end else {
                throw CalCtlError.validation("--start and --end must be supplied together")
            }
            let parsedStart = try DateParser.parseTimed(start)
            let parsedEnd = try DateParser.parseTimed(end)
            guard parsedEnd > parsedStart else { throw CalCtlError.validation("Event end must be after start") }
            startDate = parsedStart
            endDate = parsedEnd
            changed = true
        }

        if location != nil || clearLocation || notes != nil || clearNotes {
            changed = true
        }
        guard changed else { throw CalCtlError.validation("No update fields supplied") }

        return UpdateEventPreflight(title: cleanedTitle, startDate: startDate, endDate: endDate, span: parsedSpan)
    }

    public static func validateSpan(_ raw: String) throws -> EventSpan {
        guard let span = EventSpan(rawValue: raw) else {
            throw CalCtlError.validation("Span must be 'this' or 'future'")
        }
        return span
    }
}

public enum EventSpan: String, CaseIterable, ExpressibleByArgumentString {
    case this
    case future

    public var description: String { rawValue }
}

public protocol ExpressibleByArgumentString {
    init?(rawValue: String)
}
