# Limitations

`calctl` intentionally has a narrow scope for the public readiness baseline.

## Supported

- Calendar event authorization status and access requests.
- Calendar listing.
- Local aliases for calendar IDs.
- Event list/show.
- Event create/update/delete with guarded writes.
- Timed events with explicit timezone.
- All-day event creation.
- Basic location, notes, URL, and alarm-minute fields.
- Recurring event update/delete span selection for `this` or `future`.

## Not Supported

- Reminders.
- Reminders permission.
- Attendee or invite management.
- Sending invitations.
- Recurrence rule creation.
- Calendar creation, update, or deletion.
- Direct cloud provider APIs.
- Telemetry or network sync.
- Non-EventKit calendar backends.

## Known Caveats

- Full Calendar access is required for read/show/update/delete. Write-only access is insufficient.
- EventKit event identifiers can become stale after sync, account changes, or app relaunch.
- `--span future` on recurring events can affect multiple future occurrences.
- Create/update responses omit notes by default and currently do not offer an output flag to include notes.
- Delete snapshots always omit notes.
- Runtime errors are JSON, but Swift ArgumentParser usage errors may be non-JSON.
