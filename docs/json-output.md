# JSON Output

Successful runtime command output and runtime validation failures are JSON objects. Swift ArgumentParser usage errors, such as missing required options, missing required arguments, or unknown flags, may be non-JSON because they occur before command `run()` logic starts.

JSON is pretty-printed with sorted keys. Consumers should parse by field name, not by key order.

## Exit Taxonomy

- Exit `0`: command succeeded. Output has `"status": "success"`.
- Nonzero exit: command failed, permission was denied, validation failed, or usage parsing failed.
- Runtime failures: output usually has `"status": "error"` and an `"error"` string.
- ArgumentParser usage failures: may print non-JSON help/error text to stderr/stdout.

Notes on privacy columns:

- `Note-sensitive` specifically means the field may contain Calendar note bodies or is controlled by the notes policy.
- Event titles, times, locations, URLs, calendar titles, and source names can still be privacy-sensitive schedule data even when `Note-sensitive` is `No`.

## Shared Types

### `ValidationError`

Used by runtime validation, safety, permission, and EventKit lookup failures.

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"error"`. |
| `error` | Yes | No | Possible | string | Human-readable error. It may include an event ID, calendar ID, alias, or Calendar-provided text. |

Example:

```json
{
  "error": "Refusing to delete event without --force. First run the matching show/list command and confirm the exact item.",
  "status": "error"
}
```

### `Calendar`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `id` | Yes | No | No | string | EventKit calendar identifier. |
| `title` | Yes | No | Possible | string | Calendar titles may reveal private context. |
| `source` | Yes | No | Possible | string | Source title such as iCloud or Exchange account label. |
| `allowsModifications` | Yes | No | No | boolean | Whether EventKit allows writes to this calendar. |
| `color` | Yes | Yes | No | string or null | Hex color string when available. |

### `Event`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `id` | Yes | No | No | string | EventKit event identifier. May become stale after sync or relaunch. |
| `title` | Yes | No | Possible | string | Event titles may contain private content. |
| `calendar` | Yes | No | Possible | `Calendar` | Calendar metadata. |
| `startDate` | Yes | No | No | string | ISO 8601 UTC timestamp emitted by `ISO8601DateFormatter`. |
| `endDate` | Yes | No | No | string | ISO 8601 UTC timestamp emitted by `ISO8601DateFormatter`. |
| `allDay` | Yes | No | No | boolean | All-day flag. |
| `location` | Yes | Yes | Possible | string or null | Location text may contain private content. |
| `url` | Yes | Yes | Possible | string or null | URL may contain sensitive identifiers. |
| `hasAlarms` | Yes | No | No | boolean | Whether one or more alarms exist. |
| `hasRecurrenceRules` | Yes | No | No | boolean | Whether recurrence rules exist. |
| `notes` | Optional | Yes | Yes | string or null | Present only when `--include-notes` is explicit for list/show. Mutation and delete responses omit notes. |

## Command Result Schemas

### `AuthStatusResult`

Command: `calctl auth status`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `entity` | Yes | No | No | string | Currently `"event"`. |
| `authorizationStatus` | Yes | No | No | string | One of `notDetermined`, `restricted`, `denied`, `authorized`, `writeOnly`, `fullAccess`, or `unknown`. |

### `AuthRequestResult`

Command: `calctl auth request`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | `"success"` only when access is granted. Denial returns `ValidationError` with `"Calendar access was not granted"`. |
| `entity` | Yes | No | No | string | Currently `"event"`. |
| `granted` | Yes | No | No | boolean | Always `true` in successful output. Denied access is represented as an error object, not `granted: false`. |
| `authorizationStatus` | Yes | No | No | string | Current authorization status after the request. |

### `CalendarListResult`

Command: `calctl calendars list`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `calendars` | Yes | No | Possible | array of `Calendar` | Calendar titles/sources can be private. |
| `count` | Yes | No | No | integer | Number of returned calendars. |

### `AliasListResult`

Command: `calctl alias list`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `aliases` | Yes | No | Possible | array | Alias names and IDs are local but can reveal calendar meaning. |
| `aliases[].name` | Yes | No | Possible | string | Local alias. |
| `aliases[].id` | Yes | No | No | string | Calendar ID saved for the alias. |
| `count` | Yes | No | No | integer | Number of aliases. |
| `configPath` | Yes | No | Possible | string | Local filesystem path. |

### `AliasMutationResult`

Commands: `calctl alias set`, `calctl alias remove`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `message` | Yes | No | No | string | `"Alias set"` or `"Alias removed"`. |
| `alias` | Optional | No | Possible | object | Present for `alias set`. |
| `alias.name` | Optional | No | Possible | string | Present for `alias set`. |
| `alias.id` | Optional | No | No | string | Present for `alias set`. |
| `name` | Optional | No | Possible | string | Present for `alias remove`. |
| `configPath` | Optional | No | Possible | string | Present for `alias set`. |

### `EventListResult`

Command: `calctl events list`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `events` | Yes | No | Possible | array of `Event` | Event titles, calendar metadata, location, URLs, and optional notes may be private. |
| `count` | Yes | No | No | integer | Number of returned events after limit. |

`events[].notes` is optional, nullable, and note-sensitive. It appears only with `--include-notes`.

### `EventShowResult`

Command: `calctl events show`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `event` | Yes | No | Possible | `Event` | Event fields can reveal private schedule details. |

`event.notes` is optional, nullable, and note-sensitive. It appears only with `--include-notes`.

### `EventMutationResult`

Commands: `calctl events create`, `calctl events update`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `message` | Yes | No | No | string | `"Event created"` or `"Event updated"`. |
| `event` | Yes | No | Possible | `Event` | Mutation response snapshot. |
| `event.notes` | No | N/A | Yes | absent | Notes are omitted by default for create/update responses. |

### `DeleteResult`

Command: `calctl events delete`

| Field | Required | Nullable | Note-sensitive | Type | Notes |
| --- | --- | --- | --- | --- | --- |
| `status` | Yes | No | No | string | Always `"success"` on success. |
| `message` | Yes | No | No | string | `"Event deleted"`. |
| `deletedEvent` | Yes | No | Possible | `Event` | Snapshot captured before deletion. |
| `deletedEvent.notes` | No | N/A | Yes | absent | Delete snapshots always omit notes. |

## Notes Policy

- `events list` omits `notes` unless `--include-notes` is explicit.
- `events show` omits `notes` unless `--include-notes` is explicit.
- `events create` and `events update` may write notes when `--notes` is supplied, but response JSON omits notes.
- `events delete` returns a deleted-event snapshot without notes.
