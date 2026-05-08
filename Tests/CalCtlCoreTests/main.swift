import CalCtlCore
import Foundation

struct TestFailure: Error, CustomStringConvertible { let description: String }

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected { throw TestFailure(description: "\(message): expected \(expected), got \(actual)") }
}

func expectThrows(_ message: String, _ body: () throws -> Void) throws {
    do {
        try body()
        throw TestFailure(description: "Expected throw: \(message)")
    } catch is TestFailure {
        throw TestFailure(description: "Expected throw: \(message)")
    } catch {
        return
    }
}

func jsonDict(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw TestFailure(description: "Expected JSON dictionary")
    }
    return object
}

func tempConfigStore() -> (URL, ConfigStore) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("calctl-tests-\(UUID().uuidString)", isDirectory: true)
    return (root, ConfigStore(fileURL: root.appendingPathComponent(".calctl/config.json")))
}

func mode(_ url: URL) throws -> Int {
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attrs[.posixPermissions] as? NSNumber)?.intValue ?? -1
}

let timedStart = "2026-05-08T10:00:00Z"
let timedEnd = "2026-05-08T11:00:00Z"

let tests: [(String, () throws -> Void)] = [
    ("JSON success preserves dictionary fields", {
        let dict = try jsonDict(try Output.successData(["count": 0]))
        try expectEqual(dict["status"] as? String, "success", "status")
        try expectEqual(dict["count"] as? Int, 0, "count")
    }),
    ("JSON success wraps non-dictionary result", {
        let dict = try jsonDict(try Output.successData(["a", "b"]))
        try expectEqual(dict["status"] as? String, "success", "status")
        try expectEqual(dict["result"] as? [String], ["a", "b"], "result")
    }),
    ("JSON error includes message", {
        let dict = try jsonDict(try Output.errorData("Bad thing"))
        try expectEqual(dict["status"] as? String, "error", "status")
        try expectEqual(dict["error"] as? String, "Bad thing", "error")
    }),
    ("missing config returns defaults", {
        let (root, store) = tempConfigStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let config = try store.load()
        try expectEqual(config.version, 1, "version")
        try expect(config.aliases.isEmpty, "aliases should be empty")
    }),
    ("config save creates secure directory and file", {
        let (root, store) = tempConfigStore()
        defer { try? FileManager.default.removeItem(at: root) }
        try store.save(CalCtlConfig(aliases: ["work": "calendar-id"]))
        try expectEqual(try mode(store.fileURL.deletingLastPathComponent()) & 0o777, 0o700, "config directory mode")
        try expectEqual(try mode(store.fileURL) & 0o777, 0o600, "config file mode")
    }),
    ("config save tightens existing directory", {
        let (root, store) = tempConfigStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        try store.save(CalCtlConfig())
        try expectEqual(try mode(dir) & 0o777, 0o700, "existing config directory mode")
    }),
    ("alias validation accepts supported names", {
        let (root, store) = tempConfigStore()
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["work", "work-1", "work_1", "work.1", String(repeating: "a", count: 64)] {
            _ = try store.setAlias(name: name, id: "id-\(name.count)")
        }
    }),
    ("alias validation rejects unsupported names", {
        let (root, store) = tempConfigStore()
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["", "   ", "work calendar", "work/calendar", "work:calendar", String(repeating: "a", count: 65)] {
            try expectThrows("invalid alias \(name)") { _ = try store.setAlias(name: name, id: "id") }
        }
    }),
    ("alias resolve and remove behavior", {
        let (root, store) = tempConfigStore()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try store.setAlias(name: "work", id: "calendar-id")
        try expectEqual(try store.resolve("work"), "calendar-id", "configured alias")
        try expectEqual(try store.resolve("personal"), "personal", "unknown alias")
        let removedExisting = try store.removeAlias(name: "work")
        let removedMissing = try store.removeAlias(name: "missing")
        try expect(removedExisting, "existing alias should be removed")
        try expect(!removedMissing, "missing alias should not be removed")
    }),
    ("timed ISO8601 requires timezone", {
        try expectThrows("timestamp without timezone") { _ = try DateParser.parseTimed("2026-05-08T09:00:00") }
    }),
    ("timed parser rejects date-only input", {
        try expectThrows("date-only timed input") { _ = try DateParser.parseTimed("2026-05-08") }
    }),
    ("Z and offset parse to same instant", {
        let z = try DateParser.parseTimed("2026-05-08T13:00:00Z")
        let offset = try DateParser.parseTimed("2026-05-08T09:00:00-04:00")
        try expect(abs(z.timeIntervalSince1970 - offset.timeIntervalSince1970) < 0.001, "instants differ")
    }),
    ("fractional seconds are accepted", {
        let date = try DateParser.parseTimed("2026-05-08T10:00:00.123Z")
        try expect(abs(date.timeIntervalSince1970 - 1_778_234_400.123) < 0.001, "fractional timestamp parse failed")
    }),
    ("all-day date rejects timestamp", {
        try expectThrows("all-day timestamp") { _ = try DateParser.parseAllDayDate("2026-05-08T00:00:00Z") }
        let comps = try DateParser.parseAllDayDate("2026-05-08")
        try expect(comps.year == 2026, "year parse failed")
    }),
    ("all-day date rejects invalid calendar dates", {
        for value in ["2026-02-30", "2026-13-01", "2026-00-01"] {
            try expectThrows("invalid all-day date \(value)") { _ = try DateParser.parseAllDayDate(value) }
        }
    }),
    ("all-day date trims whitespace", {
        let comps = try DateParser.parseAllDayDate("  2026-05-08\n")
        try expectEqual(comps.year, 2026, "year")
        try expectEqual(comps.month, 5, "month")
        try expectEqual(comps.day, 8, "day")
    }),
    ("event draft trims title", {
        let start = try DateParser.parseTimed(timedStart)
        let end = try DateParser.parseTimed(timedEnd)
        let draft = try EventDraft.validateTimed(title: "  Planning  ", start: start, end: end)
        try expectEqual(draft.title, "Planning", "trimmed title")
    }),
    ("event end must be after start", {
        let start = try DateParser.parseTimed("2026-05-08T10:00:00Z")
        let end = try DateParser.parseTimed("2026-05-08T09:59:00Z")
        try expectThrows("end before start") { _ = try EventDraft.validateTimed(title: "Bad", start: start, end: end) }
        try expectThrows("end equal start") { _ = try EventDraft.validateTimed(title: "Bad", start: start, end: start) }
    }),
    ("blank title rejected", {
        let start = try DateParser.parseTimed("2026-05-08T10:00:00Z")
        let end = try DateParser.parseTimed("2026-05-08T11:00:00Z")
        try expectThrows("blank title") { _ = try EventDraft.validateTimed(title: "   ", start: start, end: end) }
    }),
    ("destructive actions require force", {
        try expectThrows("force required") { try Safety.requireForce(false, action: "delete event") }
        try Safety.requireForce(true, action: "delete event")
    }),
    ("mutually exclusive flags rejected", {
        try expectThrows("exclusive flags") { try Safety.requireNotBoth(true, "--clear-notes", true, "--notes") }
        try Safety.requireNotBoth(false, "--clear-notes", false, "--notes")
        try Safety.requireNotBoth(false, "--clear-notes", true, "--notes")
        try Safety.requireNotBoth(true, "--clear-notes", false, "--notes")
    }),
    ("URL validation requires scheme and allows arbitrary schemes", {
        try expectThrows("URL without scheme") { _ = try Safety.parseURL("not a url") }
        let url = try Safety.parseURL("https://example.com/path")
        try expect(url.scheme == "https", "scheme parse failed")
        try expectEqual(try Safety.parseURL("mailto:user@example.com").scheme, "mailto", "mailto scheme")
        try expectEqual(try Safety.parseURL("webcal://example.com/feed.ics").scheme, "webcal", "webcal scheme")
    }),
    ("create preflight rejects date with timed fields", {
        try expectThrows("date/start conflict") {
            _ = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: nil, allDayDate: "2026-05-08", url: nil, alarmMinutes: [])
        }
        try expectThrows("date/end conflict") {
            _ = try EventPreflight.validateCreate(title: "Event", start: nil, end: timedEnd, allDayDate: "2026-05-08", url: nil, alarmMinutes: [])
        }
    }),
    ("create preflight rejects missing timed or all-day fields", {
        try expectThrows("missing end") {
            _ = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: nil, allDayDate: nil, url: nil, alarmMinutes: [])
        }
        try expectThrows("missing start") {
            _ = try EventPreflight.validateCreate(title: "Event", start: nil, end: timedEnd, allDayDate: nil, url: nil, alarmMinutes: [])
        }
        try expectThrows("missing date or timed pair") {
            _ = try EventPreflight.validateCreate(title: "Event", start: nil, end: nil, allDayDate: nil, url: nil, alarmMinutes: [])
        }
    }),
    ("create preflight validates all-day date", {
        let draft = try EventPreflight.validateCreate(title: "  Event  ", start: nil, end: nil, allDayDate: " 2026-05-08 ", url: nil, alarmMinutes: [])
        try expect(draft.isAllDay, "draft should be all-day")
        try expectEqual(draft.title, "Event", "trimmed title")
        try expectEqual(Calendar.current.dateComponents([.day], from: draft.startDate, to: draft.endDate).day, 1, "all-day duration")
        try expectThrows("timestamp all-day") {
            _ = try EventPreflight.validateCreate(title: "Event", start: nil, end: nil, allDayDate: "2026-05-08T00:00:00Z", url: nil, alarmMinutes: [])
        }
    }),
    ("create preflight validates timed inputs", {
        let draft = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: timedEnd, allDayDate: nil, url: nil, alarmMinutes: [])
        try expect(!draft.isAllDay, "draft should be timed")
        try expectThrows("end equal start") {
            _ = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: timedStart, allDayDate: nil, url: nil, alarmMinutes: [])
        }
        try expectThrows("invalid timed start") {
            _ = try EventPreflight.validateCreate(title: "Event", start: "2026-05-08", end: timedEnd, allDayDate: nil, url: nil, alarmMinutes: [])
        }
    }),
    ("create preflight validates URL alarm bounds and title", {
        try expectThrows("invalid URL") {
            _ = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: timedEnd, allDayDate: nil, url: "not a url", alarmMinutes: [])
        }
        try expectThrows("negative alarm") {
            _ = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: timedEnd, allDayDate: nil, url: nil, alarmMinutes: [-1])
        }
        try expectThrows("too large alarm") {
            _ = try EventPreflight.validateCreate(title: "Event", start: timedStart, end: timedEnd, allDayDate: nil, url: nil, alarmMinutes: [525601])
        }
        try expectThrows("blank title") {
            _ = try EventPreflight.validateCreate(title: "  ", start: timedStart, end: timedEnd, allDayDate: nil, url: nil, alarmMinutes: [])
        }
    }),
    ("update preflight rejects empty changes", {
        try expectThrows("no update fields") {
            _ = try EventPreflight.validateUpdate(title: nil, start: nil, end: nil, location: nil, clearLocation: false, notes: nil, clearNotes: false, span: "this")
        }
    }),
    ("update preflight validates paired start and end", {
        try expectThrows("missing update end") {
            _ = try EventPreflight.validateUpdate(title: nil, start: timedStart, end: nil, location: nil, clearLocation: false, notes: nil, clearNotes: false, span: "this")
        }
        try expectThrows("missing update start") {
            _ = try EventPreflight.validateUpdate(title: nil, start: nil, end: timedEnd, location: nil, clearLocation: false, notes: nil, clearNotes: false, span: "this")
        }
        try expectThrows("update end equal start") {
            _ = try EventPreflight.validateUpdate(title: nil, start: timedStart, end: timedStart, location: nil, clearLocation: false, notes: nil, clearNotes: false, span: "this")
        }
    }),
    ("update preflight validates span conflicts and title", {
        try expectEqual(try EventPreflight.validateSpan("this"), .this, "this span")
        try expectEqual(try EventPreflight.validateSpan("future"), .future, "future span")
        try expectThrows("bad span") { _ = try EventPreflight.validateSpan("all") }
        try expectThrows("clear/set location") {
            _ = try EventPreflight.validateUpdate(title: nil, start: nil, end: nil, location: "Room", clearLocation: true, notes: nil, clearNotes: false, span: "this")
        }
        try expectThrows("clear/set notes") {
            _ = try EventPreflight.validateUpdate(title: nil, start: nil, end: nil, location: nil, clearLocation: false, notes: "Note", clearNotes: true, span: "this")
        }
        try expectThrows("blank title") {
            _ = try EventPreflight.validateUpdate(title: "  ", start: nil, end: nil, location: nil, clearLocation: false, notes: nil, clearNotes: false, span: "this")
        }
        let draft = try EventPreflight.validateUpdate(title: "  Event  ", start: nil, end: nil, location: nil, clearLocation: false, notes: nil, clearNotes: false, span: "future")
        try expectEqual(draft.title, "Event", "trimmed title")
        try expectEqual(draft.span, .future, "span")
    }),
    ("mutation responses omit notes by default", {
        try expectEqual(EventOutputPolicy.mutationIncludeNotesByDefault, false, "mutation note output policy")
    }),
]

var failures = 0
for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures += 1
        print("FAIL \(name): \(error)")
    }
}

if failures > 0 {
    print("FAILED \(failures)/\(tests.count) tests")
    exit(1)
}
print("PASSED \(tests.count) tests")
