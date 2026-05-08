# Troubleshooting

## Output Is Not JSON

Runtime success and runtime validation errors are JSON. Swift ArgumentParser usage errors can be non-JSON because they occur before command execution starts.

Common causes:

- missing required options, such as `--title` for `events create`;
- missing required arguments, such as `EVENT_ID`;
- unknown flags;
- wrong subcommand shape.

For automation, treat non-JSON output with a nonzero exit as a usage failure and fix the command invocation.

## Calendar Access Denied

Run:

```bash
calctl auth status
```

If status is `denied`, grant access in System Settings -> Privacy & Security -> Calendars, then retry. If status is `writeOnly`, grant full Calendar access; write-only access is not enough for list/show/update/delete.

## Command May Prompt

`auth status` does not prompt. `auth request` may prompt. EventKit commands such as `calendars list` and `events list/show/create/update/delete` may prompt when status is `notDetermined`.

If you need a noninteractive script, check `auth status` first and fail closed unless status is `authorized` or `fullAccess`.

## Timezone Errors

Timed event inputs must include an explicit timezone:

```bash
2026-05-08T09:00:00-04:00
2026-05-08T13:00:00Z
```

This is rejected because it is ambiguous:

```bash
2026-05-08T09:00:00
```

All-day events use `--date YYYY-MM-DD` with no time component. All-day dates are interpreted in the current macOS calendar/timezone.

## Stale Event IDs

EventKit identifiers can change after sync, account changes, or app relaunch in some Apple workflows. If update/delete fails with `Event not found`, run a fresh `events list` or `events show` workflow and use the current ID.

For destructive operations, show the event immediately before delete and confirm the title, time, calendar, and recurrence span.

## Recurring Event Span

`--span this` affects the selected occurrence and is the default. `--span future` affects future events in the recurrence series according to EventKit behavior.

Use `future` only after explicit user approval because the blast radius is larger.

## Missing `--force`

Write commands fail before EventKit access unless `--force` is present:

```json
{
  "error": "Refusing to create event without --force. First run the matching show/list command and confirm the exact item.",
  "status": "error"
}
```

This is expected. Show the normalized action details to the user, obtain explicit approval, then retry with `--force`.

## Calendar Not Writable

Some calendars exposed by EventKit do not allow modifications. Use:

```bash
calctl calendars list --writable-only
```

Then choose a writable calendar ID or alias.

## Alias Problems

Aliases live in `~/.calctl/config.json`. Valid alias names are 1-64 characters and may contain letters, numbers, underscore, dash, and dot.

If alias resolution points at a removed calendar, run `calctl calendars list` and update the alias with the current calendar ID.
