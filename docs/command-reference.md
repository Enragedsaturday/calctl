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

## `calctl defaults show`

Shows local defaults from `~/.calctl/config.json`. If no config exists, built-in defaults are returned.

Flags: none.

Side effects: none.

TCC behavior: no Calendar access and no prompt.

Success:

```json
{
  "configPath": "/Users/local/.calctl/config.json",
  "defaultAlertMinutes": [
    1440,
    120
  ],
  "status": "success"
}
```

## `calctl defaults alerts`

Sets default alert offsets in minutes before event start.

Flags:

- `--minutes N` required and repeatable, valid range `0...525600`.

Side effects: creates or updates `~/.calctl/config.json`; the directory is set to `0700` and the file to `0600`.

TCC behavior: no Calendar access and no prompt.

Success:

```json
{
  "configPath": "/Users/local/.calctl/config.json",
  "defaultAlertMinutes": [
    1440,
    120
  ],
  "message": "Default alerts updated",
  "status": "success"
}
```

## `calctl defaults reset-alerts`

Resets default alerts to 1 day and 2 hours before event start.

Flags: none.

Side effects: creates or updates `~/.calctl/config.json`; the directory is set to `0700` and the file to `0600`.

TCC behavior: no Calendar access and no prompt.

Success:

```json
{
  "configPath": "/Users/local/.calctl/config.json",
  "defaultAlertMinutes": [
    1440,
    120
  ],
  "message": "Default alerts reset",
  "status": "success"
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
- `--include-structured-location` optional. Includes structured location objects and precise coordinates; default output reports `hasStructuredLocation` and leaves `structuredLocation` null.

Side effects: reads events.

TCC behavior: requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "count": 1,
  "events": [
    {
      "alarms": [],
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
      "hasStructuredLocation": false,
      "hasRecurrenceRules": false,
      "id": "EVENT-ID",
      "location": "Office",
      "startDate": "2026-05-08T13:00:00Z",
      "structuredLocation": null,
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
- `--include-structured-location` optional. Includes structured location objects and precise coordinates; default output reports `hasStructuredLocation` and leaves `structuredLocation` null.

Side effects: reads one event.

TCC behavior: requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "event": {
    "alarms": [],
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
    "hasStructuredLocation": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Office",
    "startDate": "2026-05-08T13:00:00Z",
    "structuredLocation": null,
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

All-day event output keeps `startDate`/`endDate` for compatibility and also includes `startDateOnly`, `endDateOnly`, and `endDateSemantics: "exclusive"`. Use the date-only fields for display and all-day date math.

Flags:

- `--title TITLE` required.
- `--force` required.
- `--calendar CALENDAR_ID_OR_ALIAS` optional. Omit to use the macOS default calendar for new events.
- `--start TIMESTAMP` and `--end TIMESTAMP` required for timed events.
- `--date YYYY-MM-DD` required for all-day events and mutually exclusive with `--start`/`--end`.
- `--location TEXT` optional.
- `--structured-location-title TEXT` optional. Creates an EventKit structured location title.
- `--latitude VALUE` and `--longitude VALUE` optional and must be supplied together. Latitude must be `-90...90`; longitude must be `-180...180`. For negative longitudes, use equals form such as `--longitude=-73.9821524` so Swift ArgumentParser does not treat the value as another option.
- `--radius-meters VALUE` optional, non-negative, and requires `--latitude`/`--longitude`.
- `--notes TEXT` optional. Stored in Calendar, but omitted from the mutation response.
- `--url URL` optional. Any syntactically valid URL with a scheme is accepted.
- `--alarm-minutes N` optional and repeatable, valid range `0...525600`.
- `--no-default-alerts` optional. By default, create applies configured default alerts and then any explicit `--alarm-minutes`, removing duplicates. Built-in defaults are 1440 and 120 minutes before start.

Mutation responses include `hasStructuredLocation` but keep `structuredLocation` null, so precise coordinates are not echoed by default.

Side effects: writes a new event to Calendar.

TCC behavior: pure validation and `--force` checks run before EventKit access. A valid write requires full Calendar access. If status is `notDetermined`, EventKit commands may prompt.

Success:

```json
{
  "event": {
    "alarms": [
      {
        "minutesBeforeStart": 1440,
        "relativeOffsetSeconds": -86400
      },
      {
        "minutesBeforeStart": 120,
        "relativeOffsetSeconds": -7200
      }
    ],
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
    "hasStructuredLocation": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Office",
    "startDate": "2026-05-08T13:00:00Z",
    "structuredLocation": null,
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
    "alarms": [],
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
    "hasStructuredLocation": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Room B",
    "startDate": "2026-05-08T14:00:00Z",
    "structuredLocation": null,
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
    "alarms": [],
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
    "hasStructuredLocation": false,
    "hasRecurrenceRules": false,
    "id": "EVENT-ID",
    "location": "Office",
    "startDate": "2026-05-08T13:00:00Z",
    "structuredLocation": null,
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
