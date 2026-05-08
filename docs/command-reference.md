# Command Reference

`calctl` commands print JSON for successful runtime execution and runtime validation errors. Swift ArgumentParser usage errors, such as missing required options or unknown flags, may print standard non-JSON CLI help/error text before command execution begins.

Timed timestamps must be ISO 8601 and include an explicit timezone, for example `2026-05-08T09:00:00-04:00` or `2026-05-08T13:00:00Z`.

## `calctl auth status`

Shows EventKit Calendar authorization status.

Flags: none.

Side effects: none.

TCC behavior: does not prompt.

Success:

```json
{
  "authorizationStatus": "fullAccess",
  "entity": "event",
  "status": "success"
}
```

Runtime error: no normal runtime validation failure is expected for this command. If a runtime error is emitted, it uses the standard validation error shape:

```json
{
  "error": "Error message",
  "status": "error"
}
```

## `calctl auth request`

Requests full Calendar access.

Flags: none.

Side effects: may show a macOS Calendar privacy prompt and may change the local TCC decision for the built binary.

TCC behavior: prompts if macOS decides a prompt is available. If access is granted, output is a success object with `granted: true`. If the user denies access, output is a single JSON error object and the command exits nonzero.

Success:

```json
{
  "authorizationStatus": "fullAccess",
  "entity": "event",
  "granted": true,
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Calendar access was not granted",
  "status": "error"
}
```

## `calctl calendars list`

Lists EventKit calendars.

Flags:

- `--writable-only` optional. Only return calendars that allow event modifications.

Side effects: reads calendar metadata only.

TCC behavior: requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "calendars": [
    {
      "allowsModifications": true,
      "color": "#2A9D8F",
      "id": "CALENDAR-ID",
      "source": "iCloud",
      "title": "Work"
    }
  ],
  "count": 1,
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Calendar access denied. Grant access in System Settings -> Privacy & Security -> Calendars.",
  "status": "error"
}
```

## `calctl alias list`

Lists local calendar aliases from `~/.calctl/config.json`.

Flags: none.

Side effects: none.

TCC behavior: no Calendar access and no prompt.

Success:

```json
{
  "aliases": [
    {
      "id": "CALENDAR-ID",
      "name": "work"
    }
  ],
  "configPath": "/Users/local/.calctl/config.json",
  "count": 1,
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "The data could not be read because it is not in the correct format.",
  "status": "error"
}
```

## `calctl alias set NAME CALENDAR_ID`

Creates or replaces a local alias. Alias names must be 1-64 characters and may contain letters, numbers, underscore, dash, and dot.

Arguments:

- `NAME` required.
- `CALENDAR_ID` required.

Side effects: creates or updates `~/.calctl/config.json`; the directory is set to `0700` and the file to `0600`.

TCC behavior: no Calendar access and no prompt.

Success:

```json
{
  "alias": {
    "id": "CALENDAR-ID",
    "name": "work"
  },
  "configPath": "/Users/local/.calctl/config.json",
  "message": "Alias set",
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Alias must be 1-64 chars: letters, numbers, underscore, dash, dot",
  "status": "error"
}
```

## `calctl alias remove NAME`

Removes a local alias.

Arguments:

- `NAME` required.

Side effects: updates `~/.calctl/config.json` if the alias exists.

TCC behavior: no Calendar access and no prompt.

Success:

```json
{
  "message": "Alias removed",
  "name": "work",
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Alias not found: work",
  "status": "error"
}
```

## `calctl events list`

Lists events in a required date range, optionally scoped to one calendar.

Flags:

- `--from TIMESTAMP` required.
- `--to TIMESTAMP` required.
- `--calendar CALENDAR_ID_OR_ALIAS` optional. Omit to search all event calendars.
- `--limit N` optional, default `200`, valid range `1...5000`.
- `--include-notes` optional. Includes note bodies; notes are omitted by default.

Side effects: reads events.

TCC behavior: requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "count": 1,
  "events": [
    {
      "allDay": false,
      "calendar": {
        "allowsModifications": true,
        "color": "#2A9D8F",
        "id": "CALENDAR-ID",
        "source": "iCloud",
        "title": "Work"
      },
      "endDate": "2026-05-08T14:00:00Z",
      "hasAlarms": false,
      "hasRecurrenceRules": false,
      "id": "EVENT-ID",
      "location": "Office",
      "startDate": "2026-05-08T13:00:00Z",
      "title": "Project review",
      "url": null
    }
  ],
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Timed dates must include an explicit timezone: use Z or +/-HH:MM",
  "status": "error"
}
```

## `calctl events show EVENT_ID`

Shows one event.

Arguments:

- `EVENT_ID` required.

Flags:

- `--include-notes` optional. Includes note bodies; notes are omitted by default.

Side effects: reads one event.

TCC behavior: requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "event": {
    "allDay": false,
    "calendar": {
      "allowsModifications": true,
      "color": "#2A9D8F",
      "id": "CALENDAR-ID",
      "source": "iCloud",
      "title": "Work"
    },
    "endDate": "2026-05-08T14:00:00Z",
    "hasAlarms": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Office",
    "startDate": "2026-05-08T13:00:00Z",
    "title": "Project review",
    "url": null
  },
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Event not found: EVENT-ID",
  "status": "error"
}
```

## `calctl events create`

Creates a timed or all-day event.

Flags:

- `--title TITLE` required.
- `--force` required.
- `--calendar CALENDAR_ID_OR_ALIAS` optional. Omit to use the macOS default calendar for new events.
- `--start TIMESTAMP` and `--end TIMESTAMP` required for timed events.
- `--date YYYY-MM-DD` required for all-day events and mutually exclusive with `--start`/`--end`.
- `--location TEXT` optional.
- `--notes TEXT` optional. Stored in Calendar, but omitted from the mutation response.
- `--url URL` optional. Any syntactically valid URL with a scheme is accepted.
- `--alarm-minutes N` optional and repeatable, valid range `0...525600`.

Side effects: writes a new event to Calendar.

TCC behavior: pure validation and `--force` checks run before EventKit access. A valid write requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "event": {
    "allDay": false,
    "calendar": {
      "allowsModifications": true,
      "color": "#2A9D8F",
      "id": "CALENDAR-ID",
      "source": "iCloud",
      "title": "Work"
    },
    "endDate": "2026-05-08T14:00:00Z",
    "hasAlarms": true,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Office",
    "startDate": "2026-05-08T13:00:00Z",
    "title": "Project review",
    "url": "https://example.com"
  },
  "message": "Event created",
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Refusing to create event without --force. First run the matching show/list command and confirm the exact item.",
  "status": "error"
}
```

## `calctl events update EVENT_ID`

Updates one event.

Arguments:

- `EVENT_ID` required.

Flags:

- `--force` required.
- `--title TITLE` optional.
- `--start TIMESTAMP` and `--end TIMESTAMP` optional but must be supplied together.
- `--location TEXT` optional.
- `--clear-location` optional and mutually exclusive with `--location`.
- `--notes TEXT` optional. Stored in Calendar, but omitted from the mutation response.
- `--clear-notes` optional and mutually exclusive with `--notes`.
- `--span this|future` optional, default `this`.

At least one update field must be supplied.

Side effects: writes changes to Calendar.

TCC behavior: pure validation and `--force` checks run before EventKit access. A valid update requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "event": {
    "allDay": false,
    "calendar": {
      "allowsModifications": true,
      "color": "#2A9D8F",
      "id": "CALENDAR-ID",
      "source": "iCloud",
      "title": "Work"
    },
    "endDate": "2026-05-08T15:00:00Z",
    "hasAlarms": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Room B",
    "startDate": "2026-05-08T14:00:00Z",
    "title": "Updated review",
    "url": null
  },
  "message": "Event updated",
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "No update fields supplied",
  "status": "error"
}
```

## `calctl events delete EVENT_ID`

Deletes one event and returns a note-free snapshot of the deleted event.

Arguments:

- `EVENT_ID` required.

Flags:

- `--force` required.
- `--span this|future` optional, default `this`.

Side effects: deletes an event from Calendar.

TCC behavior: pure validation and `--force` checks run before EventKit access. A valid delete requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "deletedEvent": {
    "allDay": false,
    "calendar": {
      "allowsModifications": true,
      "color": "#2A9D8F",
      "id": "CALENDAR-ID",
      "source": "iCloud",
      "title": "Work"
    },
    "endDate": "2026-05-08T14:00:00Z",
    "hasAlarms": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Office",
    "startDate": "2026-05-08T13:00:00Z",
    "title": "Project review",
    "url": null
  },
  "message": "Event deleted",
  "status": "success"
}
```

Runtime error:

```json
{
  "error": "Span must be 'this' or 'future'",
  "status": "error"
}
```
