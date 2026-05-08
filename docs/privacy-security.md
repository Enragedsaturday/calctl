# Privacy and Security

`calctl` is designed as a local-first Calendar CLI. The application source uses EventKit and local filesystem configuration only.

## Local-Only Behavior

- No network calls are used in the app source.
- No telemetry is used.
- No cloud APIs are called directly.
- No Reminders permission is requested.
- Calendar data is accessed through the local macOS EventKit database and the accounts already configured on the Mac.

EventKit itself may reflect calendars synced by Apple or third-party account providers configured in Calendar.app. `calctl` does not add another sync or cloud transport layer.

## Notes Policy

Event notes can contain sensitive free-form text. To reduce accidental disclosure:

- `events list` omits notes unless `--include-notes` is explicit.
- `events show` omits notes unless `--include-notes` is explicit.
- `events create` and `events update` do not echo notes in response JSON.
- `events delete` returns a deleted-event snapshot without notes.

Agents and scripts should treat titles, locations, URLs, calendar names, and source names as potentially sensitive too.

## Guarded Writes

`events create`, `events update`, and `events delete` require `--force`. This flag is intentionally not a complete approval system; it is a last CLI-level guard. Agent integrations should show normalized action details to the user and obtain explicit approval before passing `--force`.

## Alias Storage

Aliases are stored locally at:

```text
~/.calctl/config.json
```

The config directory is created or tightened to mode `0700`; the config file is written with mode `0600`. Alias values are local calendar IDs. Alias names can still reveal calendar meaning, so avoid sharing config output unless needed.

## Data Sharing Guidance

Before sending command output to another tool, service, log, or chat, consider whether it contains:

- calendar titles or source account labels;
- event titles;
- locations;
- URLs with tokens or case identifiers;
- notes included with `--include-notes`;
- local filesystem paths from alias commands.

Prefer summarizing only the minimum needed fields.
