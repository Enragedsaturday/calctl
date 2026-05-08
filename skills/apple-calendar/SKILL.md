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

## Permission Notes

```bash
calctl auth status
calctl auth request
```

- `auth status` does not prompt.
- `auth request` may show a macOS Calendar privacy prompt.
- EventKit commands may prompt if status is `notDetermined`.
- Full Calendar access is required for list/show/update/delete. Write-only Calendar access is insufficient.
- If access is denied, the local operator must grant Calendar access in System Settings -> Privacy & Security -> Calendars.

## Safety Rules

1. Reads may run locally after Calendar permission is granted.
2. Never pass `--force` for create/update/delete until the user approves the normalized action details.
3. Notes can be sensitive. Do not request or display notes unless necessary; use `--include-notes` only when the user asked or the task requires it.
4. Create/update responses omit notes by default even when notes are written. Delete snapshots omit notes.
5. Timed inputs must include an explicit timezone (`Z` or `±HH:MM`). Ask if the timezone is ambiguous.
6. For update/delete, show the event immediately before the write and confirm it is the intended event.
7. Use `--span future` for recurring events only when the user explicitly approves future occurrences.

## Approval Templates

Create approval:

```text
I will create this Apple Calendar event locally:
Title: <title>
Calendar: <calendar title/alias/ID or default calendar>
When: <start/end with timezone or all-day date>
Location: <location or none>
Notes: <none / present but not displayed / displayed with approval>
URL: <url or none>
Alarms: <alarm minutes or none>

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
- Missing `--force`: this is expected before approval. Get approval, then rerun with `--force`.
- Recurrence uncertainty: default to `--span this`; ask before using `--span future`.
- Retry policy: retry only after changing the cause, such as permission, stale ID, invalid timestamp, or missing approval. Do not repeat a write blindly.

## Verification Checklist

- [ ] Operation stayed local unless sharing was approved.
- [ ] Permission status was checked when needed.
- [ ] Notes were omitted unless explicitly needed.
- [ ] Timed dates include explicit timezone.
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
- Runtime errors are JSON, but CLI usage errors may be non-JSON.

## Local Overlay Guidance

Public skill defaults are intentionally generic. A local operator may maintain a private overlay with user-specific calendar aliases, preferred timezone assumptions, naming conventions, approval policies, or data-sharing restrictions. Keep that overlay outside the public skill and do not publish private calendar details.
