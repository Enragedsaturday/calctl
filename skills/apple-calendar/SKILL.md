---
name: apple-calendar
description: "Use when managing Apple Calendar events locally on macOS with calctl: check Calendar permission, list calendars/events, create/update/delete events only after explicit approval, parse JSON output, and keep calendar data local unless the user approves sharing."
version: 1.0.0
author: CalCTL contributors
license: 0BSD
platforms: [macos]
metadata:
  hermes:
    tags: [Calendar, EventKit, macOS, scheduling, local-first]
    command: calctl
    public_safe: true
prerequisites:
  commands: [calctl]
---

# Apple Calendar via calctl

## Overview

Use `calctl` for local-only Apple Calendar event operations on macOS. `calctl` is a Swift/EventKit CLI with JSON runtime output, Calendar-only permissions, note-safe defaults, and guarded writes.

Calendar contents are private. Keep reads and writes local unless the user explicitly approves sharing specific calendar details with another tool or service.

## When to Use

- The user asks about Apple Calendar, Calendar.app, events, schedule, availability, or calendar cleanup.
- The user wants events listed from local Apple/iCloud/Exchange calendars exposed through EventKit.
- The user wants a calendar event created, updated, or deleted; use this skill to normalize details, obtain approval, run the guarded write, and verify the result.

## When Not to Use

- Reminders or task lists. `calctl` does not manage Reminders.
- Google Calendar or another provider directly, unless the provider is exposed through local Apple Calendar/EventKit.
- Any workflow that requires attendee management, invitations, recurrence creation, calendar creation/deletion, or cloud APIs.
- Sharing private or sensitive identifiers with external services without explicit user approval.

## One-Time First-Run Setup

Run setup once per Mac/user/profile before relying on this skill unattended:

```bash
calctl --version
calctl auth request
calctl auth status
calctl calendars list --writable-only
calctl defaults show
```

Setup goals:

1. **Calendar Full Access:** `calctl auth request` should trigger/confirm the macOS Calendar permission. The final acceptable status is `authorized`/`fullAccess`. If denied, the local operator must grant Calendar access in System Settings -> Privacy & Security -> Calendars.
2. **Writable calendar discovery:** verify at least one writable calendar exists and save useful aliases with `calctl alias set NAME CALENDAR_ID`.
3. **Default alerts:** read `calctl defaults show`. Those `defaultAlertMinutes` are the skill default for future creates unless the user states different alerts or no alerts. The user may set one or more default alerts, e.g. `calctl defaults alerts --minutes 1440 --minutes 120 --minutes 15`. To use no alerts for a specific event, pass `--no-default-alerts` after approval.
4. **Location permissions:** `calctl` itself does not need Location Services permission. The skill verifies/normalizes locations via explicit lookup, writes resolvable address strings or approved structured coordinates, and Calendar.app/system settings decide whether time-to-leave behavior is available.

Do not request Automation, Reminders, Contacts, Mail, Messages, Full Disk Access, or unrelated permissions for this skill unless a future feature explicitly needs it and the user approves.

## Safety Rules

1. Reads may run locally after Calendar permission is granted.
2. Never pass `--force` for create/update/delete until the user approves the normalized action details.
3. Notes can be sensitive. Do not request or display notes unless necessary; use `--include-notes` only when the user asked or the task requires it.
4. Create/update responses omit notes by default even when notes are written. Delete snapshots omit notes.
5. Timed inputs must include an explicit timezone (`Z` or `±HH:MM`). Ask if the timezone is ambiguous.
6. For update/delete, show the event immediately before the write and confirm it is the intended event.
7. Use `--span future` for recurring events only when the user explicitly approves future occurrences.
8. Before creating an event, inspect the saved default alerts with `calctl defaults show` unless already known from first-run setup. Use those `defaultAlertMinutes` by default; the user can have any number of default alerts. Override only when the user states explicit alert minutes or asks for no alerts (`--no-default-alerts`). CalCTL's standard initial default is 1 day and 2 hours before start (`1440`, `120` minutes).
9. Ambiguous or general locations must be looked up and confirmed before writing. `calctl` does not geocode; use a maps lookup outside `calctl` only when the user approves/needs it, then confirm the exact title/address/coordinates before passing structured location fields.
10. EventKit does not expose Apple Calendar's traffic-aware time-to-leave/travel-time alert API. If a confirmed structured location is supplied, Calendar may offer time-to-leave behavior according to system settings, but do not promise or claim that `calctl` forced it.

## Approval Templates

Create approval:

```text
I will create this Apple Calendar event locally:
Title: <title>
Calendar: <calendar title/alias/ID or default calendar>
When: <start/end with timezone or all-day date>
Location: <location or none>
Structured location: <none / confirmed title and coordinates>
Notes: <none / present but not displayed / displayed with approval>
URL: <url or none>
Alarms: <configured defaults from `calctl defaults show` / explicit minutes / none with --no-default-alerts>
Time-to-leave: <not forced by calctl; may be handled by Calendar if structured location and system settings allow>

Approve creating this event?
```

Update approval:

```text
I will update this Apple Calendar event locally:
Event ID: <event id>
Current: <title, time, calendar>
Changes: <field-by-field changes>
Recurring span: <this or future>
Notes: <unchanged / cleared / replaced but not displayed / displayed with approval>

Approve updating this event?
```

Delete approval:

```text
I will delete this Apple Calendar event locally:
Event ID: <event id>
Title: <title>
Calendar: <calendar title/alias/ID>
When: <start/end with timezone or all-day date>
Recurring span: <this or future>

Approve deleting this event?
```

## Quick Reference

Calendars and aliases:

```bash
calctl calendars list
calctl calendars list --writable-only
calctl alias set work CALENDAR_ID
calctl alias list
calctl alias remove work
```

Defaults:

```bash
calctl defaults show
calctl defaults alerts --minutes 1440 --minutes 120
calctl defaults reset-alerts
```

List events:

```bash
calctl events list \
  --calendar work \
  --from 2026-05-08T00:00:00-04:00 \
  --to 2026-05-09T00:00:00-04:00
```

Show event:

```bash
calctl events show EVENT_ID
calctl events show EVENT_ID --include-notes
```

Create event after approval:

```bash
calctl events create \
  --calendar work \
  --title "Project review" \
  --start 2026-05-08T09:00:00-04:00 \
  --end 2026-05-08T10:00:00-04:00 \
  --location "Office" \
  --alarm-minutes 15 \
  --force
```

Create with confirmed structured location after approval:

```bash
calctl events create \
  --calendar work \
  --title "Project review" \
  --start 2026-05-08T09:00:00-04:00 \
  --end 2026-05-08T10:00:00-04:00 \
  --location "Office" \
  --structured-location-title "Office, 123 Example St" \
  --latitude 40.7128 \
  --longitude=-74.0060 \
  --radius-meters 100 \
  --force
```

Create all-day event after approval:

```bash
calctl events create --calendar work --title "Office closed" --date 2026-05-08 --force
```

Update event after approval:

```bash
calctl events update EVENT_ID \
  --title "New title" \
  --start 2026-05-08T10:00:00-04:00 \
  --end 2026-05-08T11:00:00-04:00 \
  --force
```

Delete event after approval:

```bash
calctl events delete EVENT_ID --span this --force
```

## JSON Parsing and Verification

- Parse stdout as JSON for successful runtime commands and runtime validation errors.
- Require `"status": "success"` before trusting result fields.
- For runtime failures, read `"error"` and stop unless the user asks to retry with changed inputs.
- Swift ArgumentParser usage errors may be non-JSON. Treat non-JSON output with nonzero exit as a command construction bug and fix the invocation.
- Verify writes by reading back with `calctl events show EVENT_ID` after create/update. For delete, use the `deletedEvent` snapshot returned by the delete command.
- Do not assume JSON key order.
- All-day events include `startDateOnly`, `endDateOnly`, and `endDateSemantics: "exclusive"`; use these for display. `startDate`/`endDate` remain for compatibility and are UTC serializations of floating/default-timezone all-day dates.
- Alarm details are exposed in `alarms`; before-start relative alarms use nonpositive `relativeOffsetSeconds` and `minutesBeforeStart`.
- Event JSON includes `hasStructuredLocation` by default, but `structuredLocation` remains null unless `events list/show --include-structured-location` is explicit. Only request precise coordinates when needed and approved.

Expected write result keys:

- create/update: `status`, `message`, `event`.
- delete: `status`, `message`, `deletedEvent`.
- notes are absent from mutation and delete results.

## Failure Handling

- Denied TCC: explain that Calendar access must be granted in System Settings -> Privacy & Security -> Calendars; do not loop on the same command.
- Write-only TCC: explain that full Calendar access is required for read/show/update/delete.
- Stale event ID: run a fresh list/show search and ask the user to confirm the current event before retrying a write.
- JSON parse failure: check whether the command failed during ArgumentParser usage; fix flags/arguments before retrying.
- Timezone ambiguity: ask for timezone or use a clearly stated user-provided default. Do not silently invent an offset.
- Location ambiguity: ask for the exact place/address. If the user gives a general place name, look it up and confirm the selected result before using structured fields.
- Alert ambiguity: ask whether to use the configured defaults, explicit alert minutes, no alerts with `--no-default-alerts`, or a saved defaults update.
- Missing `--force`: this is expected before approval. Get approval, then rerun with `--force`.
- Recurrence uncertainty: default to `--span this`; ask before using `--span future`.
- Retry policy: retry only after changing the cause, such as permission, stale ID, invalid timestamp, or missing approval. Do not repeat a write blindly.

## Verification Checklist

- [ ] Operation stayed local unless sharing was approved.
- [ ] Permission status was checked when needed.
- [ ] Notes were omitted unless explicitly needed.
- [ ] Timed dates include explicit timezone.
- [ ] Alert defaults or explicit/no-alert choice were confirmed.
- [ ] Ambiguous/general locations were looked up and confirmed before structured location write.
- [ ] Create/update/delete details were approved before `--force`.
- [ ] JSON was parsed and `status` was checked.
- [ ] Write was verified by show/readback, or delete snapshot was reported.
- [ ] Final response includes concise proof: command class, event ID/title/time/calendar, and any residual risk.

## Limitations

- Calendar events only; no Reminders.
- No attendee/invite management.
- No recurrence creation.
- No calendar creation/deletion.
- No direct cloud Calendar APIs.
- EventKit IDs can become stale after sync or relaunch.
- Create/update/delete responses omit notes.
- `calctl` cannot force Apple Calendar time-to-leave alerts; it can only provide location/structured coordinates for Calendar to use when supported by local settings.
- Runtime errors are JSON, but CLI usage errors may be non-JSON.

## Local Overlay Guidance

Public skill defaults are intentionally generic. A local operator may maintain a private overlay with user-specific calendar aliases, preferred timezone assumptions, naming conventions, approval policies, or data-sharing restrictions. Keep that overlay outside the public skill and do not publish private calendar details.
