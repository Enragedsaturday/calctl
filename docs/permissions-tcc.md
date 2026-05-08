# Permissions and TCC

macOS controls Calendar access through Transparency, Consent, and Control (TCC). `calctl` uses EventKit locally and requests Calendar event access only; it does not request Reminders access.

## Access Level

`calctl` requires full Calendar access for the normal CLI workflow. Write-only Calendar access is insufficient because listing calendars, listing events, showing events, updating events, and deleting events all require reading existing Calendar data. Even a create-first workflow usually needs readback verification.

On macOS 14+ with current SDKs, full access uses `NSCalendarsFullAccessUsageDescription`. The release build also includes `NSCalendarsUsageDescription` for compatibility with older behavior.

## Prompt Behavior

- `calctl auth status` checks status and does not prompt.
- `calctl auth request` asks EventKit for full Calendar access and may prompt.
- `calctl calendars list`, `calctl events list`, `calctl events show`, and valid write commands call EventKit and may prompt if status is `notDetermined`.
- Some write validation failures happen before EventKit access, including missing `--force`, malformed dates, invalid spans, invalid URLs, invalid alarm values, and conflicting clear/set flags.

## Status Values

`calctl auth status` returns:

- `notDetermined`: no TCC decision yet.
- `restricted`: access is blocked by macOS policy.
- `denied`: the user denied Calendar access.
- `authorized`: older macOS full-access status.
- `writeOnly`: write-only Calendar access; insufficient for this CLI.
- `fullAccess`: full Calendar access.
- `unknown`: unrecognized future status.

## Recovering From Denied Access

1. Open System Settings.
2. Go to Privacy & Security -> Calendars.
3. Enable Calendar access for the terminal app or signed `calctl` binary context shown by macOS.
4. Re-run `calctl auth status`.

If the app does not appear, run `calctl auth request` from the same terminal or reinstall/rebuild the binary and try again. If macOS has cached a denial for a previous binary identity, you may need to remove and re-grant the entry in System Settings.

## Release Packaging Checks

Use:

```bash
scripts/build-release.sh
scripts/verify-release.sh
```

The verifier checks that the release binary exists, exposes version/help, embeds Info.plist content, includes the Calendar entitlement, excludes the Reminders entitlement, and contains Calendar usage strings.
