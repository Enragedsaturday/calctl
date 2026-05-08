# calctl

`calctl` is a local-only macOS Calendar command-line tool built on Apple EventKit. Command execution results are JSON, the release build embeds the required Calendar privacy strings in the Mach-O binary, and write/destructive operations require `--force` so agents and scripts do not silently mutate your calendar by accident.

## Status

Early `0.1.0` release. Calendar events only. Reminders are deliberately out of scope because Calendar and Reminders should request separate macOS privacy permissions.

## Requirements

- macOS 13+
- Swift 5.9+ / Xcode Command Line Tools
- Calendar permission granted locally through macOS TCC

## Install from source

```bash
git clone https://github.com/Enragedsaturday/calctl.git
cd calctl
scripts/build-release.sh
sudo cp .build/release/calctl /usr/local/bin/calctl
```

The build script:

1. builds only the `calctl` product in release mode;
2. embeds `Info.plist` via SwiftPM linker settings;
3. ad-hoc signs the binary with the `com.apple.security.personal-information.calendars` entitlement.

Verify the privacy packaging:

```bash
codesign -dv --verbose=4 .build/release/calctl 2>&1 | grep 'Info.plist'
codesign -d --entitlements :- .build/release/calctl
otool -l .build/release/calctl | grep -A4 -B2 '__info_plist'
```

## Permissions

Check status without prompting:

```bash
calctl auth status
```

Request full Calendar access:

```bash
calctl auth request
```

Apple's EventKit documentation says apps must obtain permission before accessing calendar data and should request only the access level needed. `calctl` requests full Calendar access because listing, showing, updating, and deleting events require reading existing calendar data. EventKit write-only access can create events, but it cannot read calendars or events — including events the app created — so it is insufficient for `list`, `show`, `update`, or `delete` workflows. `calctl` does **not** request Reminders access.

On macOS 14+ / current SDKs, full calendar read/write access requires `NSCalendarsFullAccessUsageDescription` in `Info.plist`. `calctl` also includes the older `NSCalendarsUsageDescription` compatibility key for older macOS behavior.

References:

- Apple `EKEventStore`: https://developer.apple.com/documentation/eventkit/ekeventstore
- Apple Event Store access: https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- Apple `NSCalendarsFullAccessUsageDescription`: https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSCalendarsFullAccessUsageDescription
- Apple `requestWriteOnlyAccessToEvents`: https://developer.apple.com/documentation/eventkit/ekeventstore/requestwriteonlyaccesstoevents(completion:)

## Commands

### List calendars

```bash
calctl calendars list
calctl calendars list --writable-only
```

### Aliases

Aliases are local only at `~/.calctl/config.json`; the directory is written with `0700` permissions and the config file with `0600` permissions.

```bash
calctl alias set work CALENDAR_ID
calctl alias list
calctl alias remove work
```

### List events

Timed date ranges must be ISO 8601 and must include an explicit timezone (`Z` or `±HH:MM`). This avoids silently interpreting ambiguous local times incorrectly.

```bash
calctl events list \
  --calendar work \
  --from 2026-05-08T00:00:00-04:00 \
  --to 2026-05-09T00:00:00-04:00
```

Omit `--calendar` to search all calendars:

```bash
calctl events list \
  --from 2026-05-08T00:00:00-04:00 \
  --to 2026-05-09T00:00:00-04:00
```

Notes are omitted by default because they can contain sensitive information. Include them explicitly:

```bash
calctl events show EVENT_ID --include-notes
```

### Create events

Writes require `--force`.

Timed event:

```bash
calctl events create \
  --calendar work \
  --title "Project review" \
  --start 2026-05-08T09:00:00-04:00 \
  --end 2026-05-08T10:00:00-04:00 \
  --location "Office" \
  --notes "Bring notes" \
  --url https://example.com \
  --alarm-minutes 15 \
  --force
```

All-day event:

```bash
calctl events create --calendar work --title "Court closed" --date 2026-05-08 --force
```

All-day dates are interpreted in the user's current macOS calendar/timezone.

### Update events

```bash
calctl events update EVENT_ID \
  --title "New title" \
  --start 2026-05-08T10:00:00-04:00 \
  --end 2026-05-08T11:00:00-04:00 \
  --force
```

For recurring events, span defaults to this occurrence:

```bash
calctl events update EVENT_ID --location "Room B" --span this --force
calctl events update EVENT_ID --location "Room B" --span future --force
```

`--clear-location` conflicts with `--location`; `--clear-notes` conflicts with `--notes`. The CLI rejects those combinations.

### Delete events

```bash
calctl events show EVENT_ID
calctl events delete EVENT_ID --span this --force
```

`delete` returns a snapshot of the deleted event without notes.

## Safety model

- Runtime is local EventKit only.
- No network calls in the application source.
- No Reminders permission request.
- `auth status` does not prompt.
- Full Calendar access is requested only by `auth request` or when a command actually needs EventKit access and status is `notDetermined`.
- Writes (`create`, `update`, `delete`) require `--force`.
- Notes are omitted from reads unless `--include-notes` is explicit.
- Timed inputs require explicit timezone.
- `end` must be after `start`.
- Event URLs require a valid URL scheme.

Agent integrations should add another confirmation layer before passing `--force`.

## JSON behavior

Successful command execution and command runtime validation failures print JSON. Swift ArgumentParser usage errors, such as missing required options, may print standard CLI help/error text before command execution begins.

## Tests

This repository uses a small self-contained test runner instead of XCTest because some Command Line Tools installations do not expose XCTest to SwiftPM CLI targets.

```bash
swift run calctl-tests
swift build --product calctl
scripts/build-release.sh
```

CI also checks that the release binary contains an embedded `Info.plist` and Calendar entitlement.

## Limitations

- Calendar events only; no Reminders.
- No attendee/invite management.
- No recurrence creation yet.
- No calendar creation/deletion.
- EventKit identifiers can change after sync or app relaunch in some Apple workflows. Prefer a fresh `list`/`show` before update/delete.
- Write-only Calendar access is insufficient for this CLI because list/show/update/delete require read access.

## License

`calctl` is licensed under 0BSD, which permits use, copying, modification, and distribution for any purpose, with or without fee, and does not require preserving copyright notices, license text, or attribution. The software is provided without warranty or liability.
