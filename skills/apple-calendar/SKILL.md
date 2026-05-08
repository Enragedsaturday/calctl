---
name: apple-calendar
description: "Use when managing Apple Calendar events locally on macOS with calctl: list calendars/events, create/update/delete events with explicit approval, and keep calendar data local."
version: 1.0.0
author: John Galt / Hermes Agent
license: 0BSD
platforms: [macos]
metadata:
  hermes:
    tags: [Calendar, EventKit, macOS, scheduling, local-first]
    related_skills: [apple-reminders]
prerequisites:
  commands: [calctl]
---

# Apple Calendar via calctl

## Overview

Use `calctl` for local-only Apple Calendar event operations on macOS. `calctl` is a Swift/EventKit CLI that outputs JSON, embeds Calendar privacy usage strings, requests only Calendar access, omits notes by default, and requires `--force` for writes.

Calendar contents are private. Keep reads and writes local unless Benjamin explicitly approves sharing calendar content with a cloud service. Do not send calendar details to another platform unless the user requested it.

## When to Use

- User asks about Apple Calendar, Calendar.app, events, schedule, availability, or calendar cleanup.
- User wants events listed from local Apple/iCloud/Exchange calendars exposed through EventKit.
- User wants a calendar event created, updated, or deleted and has explicitly approved the final event details.

## When NOT to Use

- Agent reminders/alerts that do not need Apple Calendar → use Hermes `cronjob`.
- Apple Reminders tasks → use `apple-reminders`.
- Google Calendar directly → use Google Workspace tools if requested.
- Any CJIS/legal/private identifiers going to cloud → keep local or ask for explicit approval.

## Safety Rules

1. Reads may run locally after Calendar permission is granted.
2. Never pass `--force` for create/update/delete until Benjamin explicitly approves the normalized action details.
3. Before creating/updating/deleting, show:
   - title
   - calendar title/alias/ID
   - start/end or all-day date
   - timezone/offset
   - location
   - notes presence/content if relevant
   - event ID for update/delete
   - recurrence span (`this` or `future`) if applicable
4. After a write, verify by reading back with `calctl events show EVENT_ID`; for delete, report the delete snapshot returned by the command.
5. Notes can be sensitive. Do not include notes unless necessary; use `--include-notes` only when the user asked or the task requires it.
6. Timed inputs must include an explicit timezone (`Z` or `±HH:MM`). Do not guess timezone if it changes the result.
7. For destructive operations, first run `calctl events show EVENT_ID` and confirm it is the intended event.

## Setup / Permission Check

```bash
calctl auth status
calctl auth request
```

If access is denied, Benjamin must grant Calendar access in:

System Settings → Privacy & Security → Calendars

## Quick Reference

### Calendars

```bash
calctl calendars list
calctl calendars list --writable-only
calctl alias set work CALENDAR_ID
calctl alias list
calctl alias remove work
```

### List Events

```bash
calctl events list \
  --calendar work \
  --from 2026-05-08T00:00:00-04:00 \
  --to 2026-05-09T00:00:00-04:00
```

Search all calendars:

```bash
calctl events list \
  --from 2026-05-08T00:00:00-04:00 \
  --to 2026-05-09T00:00:00-04:00
```

Include notes only when required:

```bash
calctl events show EVENT_ID --include-notes
```

### Create Event

First present the proposed event to Benjamin. Only after approval:

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

All-day:

```bash
calctl events create --calendar work --title "Court closed" --date 2026-05-08 --force
```

### Update Event

Preflight:

```bash
calctl events show EVENT_ID
```

After approval:

```bash
calctl events update EVENT_ID \
  --title "New title" \
  --start 2026-05-08T10:00:00-04:00 \
  --end 2026-05-08T11:00:00-04:00 \
  --force
```

Recurring event span:

```bash
calctl events update EVENT_ID --location "Room B" --span this --force
calctl events update EVENT_ID --location "Room B" --span future --force
```

### Delete Event

Preflight:

```bash
calctl events show EVENT_ID
```

After approval:

```bash
calctl events delete EVENT_ID --span this --force
```

## Verification Checklist

- [ ] Calendar operation stayed local.
- [ ] Calendar permission status checked if needed.
- [ ] No notes exposed unless required.
- [ ] Timed dates include explicit timezone.
- [ ] Create/update/delete details were approved before `--force`.
- [ ] Write result was parsed as JSON and verified.
- [ ] Final response includes concise proof: command class run, event ID/title/time/calendar, and any residual risk.

## Common Pitfalls

1. **Passing `--force` too early.** Approval first, command second.
2. **Using timezone-less timestamps.** `calctl` rejects them; ask or infer only if context makes it unambiguous and label the assumption.
3. **Forgetting notes are sensitive.** Default omit notes; use `--include-notes` sparingly.
4. **Using stale EventKit IDs.** List/show immediately before update/delete.
5. **Recurring events.** Default span is `this`; use `future` only when explicitly approved.
6. **Write-only Calendar access.** Not enough for this skill; full Calendar access is required for read/show/update/delete.
