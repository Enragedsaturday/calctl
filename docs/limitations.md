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
- Configurable default alerts, explicit alarm-minute fields, notes, URL, plain locations, and optional structured location coordinates.
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
- Structured coordinates are omitted by default; only `events list/show --include-structured-location` emits structured location objects.
- Delete snapshots always omit notes.
- EventKit does not expose Apple Calendar's traffic-aware time-to-leave/travel-time alert API publicly. Supplying a structured location can let Calendar use its own settings, but `calctl` cannot force a time-to-leave alert.
- `calctl` does not perform network geocoding. Look up and confirm ambiguous or general locations before passing structured location fields.
- Runtime errors are JSON, but Swift ArgumentParser usage errors may be non-JSON.
