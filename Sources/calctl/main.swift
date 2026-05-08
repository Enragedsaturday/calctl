import ArgumentParser
import CalCtlCore
import EventKit
import Foundation

@main
struct CalCtl: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calctl",
        abstract: "Local-only macOS Calendar CLI using EventKit with JSON output and guarded writes.",
        version: "0.1.0",
        subcommands: [Auth.self, Calendars.self, Events.self, Alias.self],
        defaultSubcommand: Calendars.self
    )
}

// MARK: - Auth

struct Auth: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Inspect or request Calendar permission.", subcommands: [AuthStatus.self, AuthRequest.self])
}

struct AuthStatus: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "Show EventKit Calendar authorization status.")
    func run() throws {
        print(Output.success(["entity": "event", "authorizationStatus": EventKitClient.authorizationStatusString()]))
    }
}

struct AuthRequest: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "request", abstract: "Request Calendar full access. This may show a macOS privacy prompt.")
    func run() throws {
        do {
            let granted = try EventKitClient().requestEventAccess()
            if granted {
                print(Output.success(["entity": "event", "granted": true, "authorizationStatus": EventKitClient.authorizationStatusString()]))
            } else {
                print(Output.error("Calendar access was not granted"))
                throw ExitCode.failure
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

// MARK: - Calendars

struct Calendars: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Calendar commands.", subcommands: [CalendarsList.self], defaultSubcommand: CalendarsList.self)
}

struct CalendarsList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List event calendars.")

    @Flag(help: "Only show calendars that allow modifications.") var writableOnly = false

    func run() throws {
        do {
            let client = EventKitClient()
            try client.ensureEventAccess()
            let calendars = client.listCalendars(writableOnly: writableOnly)
            print(Output.success(["calendars": calendars, "count": calendars.count]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

// MARK: - Events

struct Events: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Event commands.", subcommands: [EventsList.self, EventsShow.self, EventsCreate.self, EventsUpdate.self, EventsDelete.self])
}

struct EventsList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List events in a required date range. Calendar is optional; omit for all calendars.")

    @Option(help: "Calendar ID or alias. Omit to search all event calendars.") var calendar: String?
    @Option(help: "Range start, ISO 8601 with timezone, e.g. 2026-05-08T00:00:00-04:00") var from: String
    @Option(help: "Range end, ISO 8601 with timezone, e.g. 2026-05-09T00:00:00-04:00") var to: String
    @Option(help: "Maximum returned events after sorting by start date.") var limit: Int = 200
    @Flag(help: "Include notes field in output. Notes may contain sensitive data; default omits them.") var includeNotes = false

    func run() throws {
        do {
            guard limit > 0 && limit <= 5000 else { throw CalCtlError.validation("--limit must be between 1 and 5000") }
            let start = try DateParser.parseTimed(from)
            let end = try DateParser.parseTimed(to)
            _ = try EventDraft.validateTimed(title: "range", start: start, end: end)
            let store = ConfigStore()
            let calendarID = try calendar.map { try store.resolve($0) }
            let client = EventKitClient()
            try client.ensureEventAccess()
            let events = try client.listEvents(calendarID: calendarID, from: start, to: end, limit: limit, includeNotes: includeNotes)
            print(Output.success(["events": events, "count": events.count]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

struct EventsShow: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Show one event by ID.")
    @Argument(help: "Event identifier from list/create output.") var eventID: String
    @Flag(help: "Include notes field in output. Notes may contain sensitive data; default omits them.") var includeNotes = false

    func run() throws {
        do {
            let client = EventKitClient()
            try client.ensureEventAccess()
            let event = try client.showEvent(eventID: eventID, includeNotes: includeNotes)
            print(Output.success(["event": event]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

struct EventsCreate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "create", abstract: "Create an event. Timed events require --start and --end. All-day events require --date.")

    @Option(help: "Calendar ID or alias. Omit to use the macOS default calendar for new events.") var calendar: String?
    @Option(help: "Event title.") var title: String
    @Option(help: "Timed start, ISO 8601 with timezone. Required unless --date is used.") var start: String?
    @Option(help: "Timed end, ISO 8601 with timezone. Required unless --date is used.") var end: String?
    @Option(help: "All-day event date as YYYY-MM-DD. Mutually exclusive with --start/--end.") var date: String?
    @Option(help: "Location text.") var location: String?
    @Option(help: "Notes text.") var notes: String?
    @Option(help: "URL associated with the event.") var url: String?
    @Option(help: "Add an alarm N minutes before start. Can be repeated.") var alarmMinutes: [Int] = []
    @Flag(help: "Required for writes. Prevents accidental event creation by agent/tooling.") var force = false

    func run() throws {
        do {
            try Safety.requireForce(force, action: "create event")
            let preflight = try EventPreflight.validateCreate(title: title, start: start, end: end, allDayDate: date, url: url, alarmMinutes: alarmMinutes)
            let store = ConfigStore()
            let calendarID = try calendar.map { try store.resolve($0) }
            let client = EventKitClient()
            try client.ensureEventAccess()
            let event = try client.createEvent(calendarID: calendarID, preflight: preflight, location: location, notes: notes)
            print(Output.success(["message": "Event created", "event": event]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

struct EventsUpdate: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "update", abstract: "Update one event by ID. Requires --force.")

    @Argument(help: "Event identifier.") var eventID: String
    @Option(help: "New title.") var title: String?
    @Option(help: "New timed start, ISO 8601 with timezone. Must be paired with --end.") var start: String?
    @Option(help: "New timed end, ISO 8601 with timezone. Must be paired with --start.") var end: String?
    @Option(help: "New location.") var location: String?
    @Flag(help: "Clear location.") var clearLocation = false
    @Option(help: "New notes.") var notes: String?
    @Flag(help: "Clear notes.") var clearNotes = false
    @Option(help: "Span for recurring events: this or future.") var span: String = "this"
    @Flag(help: "Required for writes.") var force = false

    func run() throws {
        do {
            try Safety.requireForce(force, action: "update event")
            let preflight = try EventPreflight.validateUpdate(
                title: title,
                start: start,
                end: end,
                location: location,
                clearLocation: clearLocation,
                notes: notes,
                clearNotes: clearNotes,
                span: span
            )
            let client = EventKitClient()
            try client.ensureEventAccess()
            let event = try client.updateEvent(eventID: eventID, preflight: preflight, location: location, clearLocation: clearLocation, notes: notes, clearNotes: clearNotes)
            print(Output.success(["message": "Event updated", "event": event]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

struct EventsDelete: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete one event by ID. Requires --force.")

    @Argument(help: "Event identifier.") var eventID: String
    @Option(help: "Span for recurring events: this or future.") var span: String = "this"
    @Flag(help: "Required for deletion.") var force = false

    func run() throws {
        do {
            try Safety.requireForce(force, action: "delete event")
            let span = try EventPreflight.validateSpan(span)
            let client = EventKitClient()
            try client.ensureEventAccess()
            let deleted = try client.deleteEvent(eventID: eventID, span: span)
            print(Output.success(["message": "Event deleted", "deletedEvent": deleted]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

// MARK: - Alias

struct Alias: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Manage local aliases for calendar IDs.", subcommands: [AliasList.self, AliasSet.self, AliasRemove.self])
}

struct AliasList: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List aliases from ~/.calctl/config.json.")
    func run() throws {
        do {
            let store = ConfigStore()
            let config = try store.load()
            let aliases = config.aliases.sorted { $0.key < $1.key }.map { ["name": $0.key, "id": $0.value] }
            print(Output.success(["aliases": aliases, "count": aliases.count, "configPath": store.fileURL.path]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

struct AliasSet: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set alias for a calendar ID.")
    @Argument var name: String
    @Argument var id: String
    func run() throws {
        do {
            let store = ConfigStore()
            _ = try store.setAlias(name: name, id: id)
            print(Output.success(["message": "Alias set", "alias": ["name": name, "id": id], "configPath": store.fileURL.path]))
        } catch {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

struct AliasRemove: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: "Remove alias.")
    @Argument var name: String
    func run() throws {
        do {
            let store = ConfigStore()
            let removed = try store.removeAlias(name: name)
            if removed { print(Output.success(["message": "Alias removed", "name": name])) }
            else { print(Output.error("Alias not found: \(name)")); throw ExitCode.failure }
        } catch let error where !(error is ExitCode) {
            print(Output.error(String(describing: error)))
            throw ExitCode.failure
        }
    }
}

// MARK: - EventKit runtime

final class EventKitClient {
    private let eventStore = EKEventStore()

    static func authorizationStatusString() -> String {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .writeOnly: return "writeOnly"
        case .fullAccess: return "fullAccess"
        @unknown default: return "unknown"
        }
    }

    func requestEventAccess() throws -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        var requestError: Error?
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                result = granted
                requestError = error
                semaphore.signal()
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                result = granted
                requestError = error
                semaphore.signal()
            }
        }
        semaphore.wait()
        if let requestError { throw requestError }
        return result
    }

    func ensureEventAccess() throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            guard try requestEventAccess() else { throw CalCtlError.unsafe("Calendar access was not granted") }
        case .writeOnly:
            throw CalCtlError.unsafe("Calendar access is write-only; full access is required for this read/write CLI")
        case .denied:
            throw CalCtlError.unsafe("Calendar access denied. Grant access in System Settings → Privacy & Security → Calendars.")
        case .restricted:
            throw CalCtlError.unsafe("Calendar access restricted by macOS policy")
        @unknown default:
            throw CalCtlError.unsafe("Unknown Calendar authorization status")
        }
    }

    func listCalendars(writableOnly: Bool) -> [[String: Any]] {
        eventStore.calendars(for: .event)
            .filter { !writableOnly || $0.allowsContentModifications }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            .map(calendarDict)
    }

    func listEvents(calendarID: String?, from: Date, to: Date, limit: Int, includeNotes: Bool) throws -> [[String: Any]] {
        let calendars: [EKCalendar]?
        if let calendarID {
            guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { throw CalCtlError.validation("Calendar not found: \(calendarID)") }
            calendars = [calendar]
        } else {
            calendars = nil
        }
        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return Array(eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }.prefix(limit)).map { eventDict($0, includeNotes: includeNotes) }
    }

    func showEvent(eventID: String, includeNotes: Bool) throws -> [String: Any] {
        guard let event = eventStore.event(withIdentifier: eventID) else { throw CalCtlError.validation("Event not found: \(eventID)") }
        return eventDict(event, includeNotes: includeNotes)
    }

    func createEvent(calendarID: String?, preflight: CreateEventPreflight, location: String?, notes: String?) throws -> [String: Any] {
        let calendar: EKCalendar
        if let calendarID {
            guard let found = eventStore.calendar(withIdentifier: calendarID) else { throw CalCtlError.validation("Calendar not found: \(calendarID)") }
            calendar = found
        } else if let found = eventStore.defaultCalendarForNewEvents {
            calendar = found
        } else {
            throw CalCtlError.validation("No default calendar for new events; pass --calendar")
        }
        guard calendar.allowsContentModifications else { throw CalCtlError.validation("Calendar does not allow modifications: \(calendar.title)") }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = preflight.title
        event.isAllDay = preflight.isAllDay
        event.startDate = preflight.startDate
        event.endDate = preflight.endDate
        event.location = location
        event.notes = notes
        event.url = preflight.url
        for minutes in preflight.alarmMinutes {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
        }
        try eventStore.save(event, span: .thisEvent, commit: true)
        return eventDict(event, includeNotes: EventOutputPolicy.mutationIncludeNotesByDefault)
    }

    func updateEvent(eventID: String, preflight: UpdateEventPreflight, location: String?, clearLocation: Bool, notes: String?, clearNotes: Bool) throws -> [String: Any] {
        guard let event = eventStore.event(withIdentifier: eventID) else { throw CalCtlError.validation("Event not found: \(eventID)") }
        guard event.calendar.allowsContentModifications else { throw CalCtlError.validation("Calendar does not allow modifications: \(event.calendar.title)") }
        if let title = preflight.title {
            event.title = title
        }
        if let startDate = preflight.startDate, let endDate = preflight.endDate {
            event.startDate = startDate; event.endDate = endDate; event.isAllDay = false
        }
        if clearLocation { event.location = nil }
        else if let location { event.location = location }
        if clearNotes { event.notes = nil }
        else if let notes { event.notes = notes }
        try eventStore.save(event, span: ekSpan(preflight.span), commit: true)
        return eventDict(event, includeNotes: EventOutputPolicy.mutationIncludeNotesByDefault)
    }

    func deleteEvent(eventID: String, span: EventSpan) throws -> [String: Any] {
        guard let event = eventStore.event(withIdentifier: eventID) else { throw CalCtlError.validation("Event not found: \(eventID)") }
        guard event.calendar.allowsContentModifications else { throw CalCtlError.validation("Calendar does not allow modifications: \(event.calendar.title)") }
        let snapshot = eventDict(event, includeNotes: false)
        try eventStore.remove(event, span: ekSpan(span), commit: true)
        return snapshot
    }

    private func ekSpan(_ span: EventSpan) -> EKSpan {
        switch span {
        case .this: return .thisEvent
        case .future: return .futureEvents
        }
    }

    private func calendarDict(_ calendar: EKCalendar) -> [String: Any] {
        [
            "id": calendar.calendarIdentifier,
            "title": calendar.title,
            "source": calendar.source.title,
            "allowsModifications": calendar.allowsContentModifications,
            "color": calendar.cgColor?.hexString ?? NSNull()
        ]
    }

    private func eventDict(_ event: EKEvent, includeNotes: Bool) -> [String: Any] {
        var dict: [String: Any] = [
            "id": event.eventIdentifier ?? "",
            "title": event.title ?? "",
            "calendar": calendarDict(event.calendar),
            "startDate": DateParser.isoString(event.startDate),
            "endDate": DateParser.isoString(event.endDate),
            "allDay": event.isAllDay,
            "location": event.location ?? NSNull(),
            "url": event.url?.absoluteString ?? NSNull(),
            "hasAlarms": event.hasAlarms,
            "hasRecurrenceRules": event.hasRecurrenceRules
        ]
        if includeNotes { dict["notes"] = event.notes ?? NSNull() }
        return dict
    }
}

extension CGColor {
    var hexString: String? {
        guard let components = components, components.count >= 3 else { return nil }
        let r = Int((components[0] * 255.0).rounded())
        let g = Int((components[1] * 255.0).rounded())
        let b = Int((components[2] * 255.0).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
