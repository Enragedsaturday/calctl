# calctl

`calctl` is a local-only macOS Calendar command-line tool built on Apple EventKit. It prints JSON for successful runtime commands and runtime validation errors, requires `--force` for create/update/delete, and omits event notes by default because notes can contain sensitive information.

## Status

Early `0.1.0` release. Calendar events only. Reminders are deliberately out of scope.

## Requirements

- macOS 13+
- Swift 5.9+ / Xcode Command Line Tools
- Full Calendar access granted locally through macOS TCC

## Install From Source

```bash
git clone https://github.com/Enragedsaturday/calctl.git
cd calctl
scripts/build-release.sh
sudo cp .build/release/calctl /usr/local/bin/calctl
```

The release build embeds Calendar privacy usage strings and is ad-hoc signed with the Calendar entitlement. Verify packaging with:

```bash
scripts/verify-release.sh
```

## Quick Start

Check permission status without prompting:

```bash
calctl auth status
```

Request full Calendar access. This may show a macOS privacy prompt:

```bash
calctl auth request
```

List calendars and create a local alias:

```bash
calctl calendars list
calctl alias set work CALENDAR_ID
```

List events in a timezone-explicit range:

```bash
calctl events list \
  --calendar work \
  --from 2026-05-08T00:00:00-04:00 \
  --to 2026-05-09T00:00:00-04:00
```

Writes require explicit confirmation by the caller before passing `--force`:

```bash
calctl events create \
  --calendar work \
  --title "Project review" \
  --start 2026-05-08T09:00:00-04:00 \
  --end 2026-05-08T10:00:00-04:00 \
  --force
```

## Documentation

- [Command Reference](docs/command-reference.md)
- [JSON Output](docs/json-output.md)
- [Permissions and TCC](docs/permissions-tcc.md)
- [Privacy and Security](docs/privacy-security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Limitations](docs/limitations.md)
- [Testing and Release Verification](docs/testing-release-verification.md)

## Safety Model

- Runtime is local EventKit only.
- No network calls, telemetry, cloud APIs, or Reminders permission requests are used by the app source.
- `auth status` does not prompt.
- `auth request` may prompt.
- EventKit commands may prompt if Calendar status is `notDetermined`.
- Full Calendar access is required for read/show/update/delete; write-only Calendar access is insufficient.
- Notes are omitted unless `--include-notes` is explicit. Create/update/delete responses omit notes.
- `create`, `update`, and `delete` require `--force`.

## Tests

This repository uses a small self-contained Swift test runner instead of XCTest because some Command Line Tools installations do not expose XCTest to SwiftPM CLI targets.

```bash
swift run calctl-tests
swift build --product calctl
scripts/test-cli-json.sh
scripts/build-release.sh
scripts/verify-release.sh
```

The opt-in EventKit E2E script is documented in [Testing and Release Verification](docs/testing-release-verification.md). Do not run it against real Calendar data unless you have created the disposable `CalCTL Test` calendar and explicitly opted in.

## License

`calctl` is licensed under 0BSD. See [LICENSE](LICENSE).
