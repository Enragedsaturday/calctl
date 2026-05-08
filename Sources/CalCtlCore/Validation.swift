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

public enum EventSpan: String, CaseIterable, ExpressibleByArgumentString {
    case this
    case future

    public var description: String { rawValue }
}

public protocol ExpressibleByArgumentString {
    init?(rawValue: String)
}
