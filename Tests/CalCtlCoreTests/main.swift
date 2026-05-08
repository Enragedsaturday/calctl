import CalCtlCore
import Foundation

struct TestFailure: Error, CustomStringConvertible { let description: String }

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
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

let tests: [(String, () throws -> Void)] = [
    ("timed ISO8601 requires timezone", {
        try expectThrows("timestamp without timezone") { _ = try DateParser.parseTimed("2026-05-08T09:00:00") }
    }),
    ("Z and offset parse to same instant", {
        let z = try DateParser.parseTimed("2026-05-08T13:00:00Z")
        let offset = try DateParser.parseTimed("2026-05-08T09:00:00-04:00")
        try expect(abs(z.timeIntervalSince1970 - offset.timeIntervalSince1970) < 0.001, "instants differ")
    }),
    ("all-day date rejects timestamp", {
        try expectThrows("all-day timestamp") { _ = try DateParser.parseAllDayDate("2026-05-08T00:00:00Z") }
        let comps = try DateParser.parseAllDayDate("2026-05-08")
        try expect(comps.year == 2026, "year parse failed")
    }),
    ("event end must be after start", {
        let start = try DateParser.parseTimed("2026-05-08T10:00:00Z")
        let end = try DateParser.parseTimed("2026-05-08T09:59:00Z")
        try expectThrows("end before start") { _ = try EventDraft.validateTimed(title: "Bad", start: start, end: end) }
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
        try Safety.requireNotBoth(false, "--clear-notes", true, "--notes")
    }),
    ("URL validation requires scheme", {
        try expectThrows("URL without scheme") { _ = try Safety.parseURL("not a url") }
        let url = try Safety.parseURL("https://example.com/path")
        try expect(url.scheme == "https", "scheme parse failed")
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
