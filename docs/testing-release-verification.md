# Testing and Release Verification

CalCTL has three test layers. Two are CI-safe and one is explicitly local-only.

## CI-safe unit and CLI checks

Run from the repository root:

```bash
swift run calctl-tests
swift build --product calctl
scripts/test-cli-json.sh
```

`scripts/test-cli-json.sh` uses a temporary `HOME` and only runs commands that do not read Calendar data or that fail during pure validation before EventKit access. It validates JSON for:

- `auth status`
- alias list/set/remove flows
- guarded create/update/delete without `--force`
- pure validation failures such as invalid dates, URLs, alarm bounds, spans, and conflicting flags

Swift ArgumentParser usage failures can be non-JSON because they occur before command execution reaches CalCTL's runtime JSON error handling.

## Release verification

Build and verify the release binary:

```bash
scripts/build-release.sh
scripts/verify-release.sh
```

The verifier checks:

- `.build/release/calctl` is executable
- `--version` and `--help` work
- the binary has embedded Info.plist entries
- the Calendar entitlement is present
- the Reminders entitlement is absent
- the Mach-O `__info_plist` section exists
- both Calendar privacy usage strings are embedded

## Opt-in local EventKit E2E

`scripts/test-e2e-calendar.sh` is **not** CI-safe and must not run automatically. It writes to Calendar through EventKit.

Safety rules:

- Requires an existing writable calendar titled exactly `CalCTL Test`.
- Uses a temporary `HOME`, so the real `~/.calctl` is untouched.
- Prints only whether the disposable calendar was found; it does not print private calendar names.
- Creates synthetic events with titles beginning `CalCTL E2E`.
- Deletes created synthetic events at the end and attempts cleanup on failure.
- Requires explicit approval:

```bash
CALCTL_E2E_APPROVED=I_UNDERSTAND_CALCTL_TEST_ONLY scripts/test-e2e-calendar.sh
```

For noninteractive local runs, also set:

```bash
CALCTL_E2E_APPROVED=I_UNDERSTAND_CALCTL_TEST_ONLY \
CALCTL_E2E_NONINTERACTIVE=I_UNDERSTAND_CALCTL_TEST_ONLY \
scripts/test-e2e-calendar.sh
```

Do not use this script on a real production calendar. It is only for a disposable local `CalCTL Test` calendar.
