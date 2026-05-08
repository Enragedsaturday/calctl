#!/usr/bin/env bash
# Verify release binary privacy packaging and basic CLI metadata.
set -euo pipefail

cd "$(dirname "$0")/.."

BIN="${CALCTL_RELEASE_BIN:-.build/release/calctl}"
if [[ ! -x "$BIN" ]]; then
  echo "release binary not found or not executable: $BIN" >&2
  echo "run scripts/build-release.sh first" >&2
  exit 1
fi

"$BIN" --version >/tmp/calctl-version.txt
"$BIN" --help | grep -q 'Local-only macOS Calendar CLI'

codesign -dv --verbose=4 "$BIN" 2>&1 | tee /tmp/calctl-codesign.txt >/dev/null
grep -q 'Info.plist entries=' /tmp/calctl-codesign.txt

codesign -d --entitlements :- "$BIN" > /tmp/calctl-entitlements.plist
grep -q 'com.apple.security.personal-information.calendars' /tmp/calctl-entitlements.plist
if grep -q 'com.apple.security.personal-information.reminders' /tmp/calctl-entitlements.plist; then
  echo "unexpected Reminders entitlement present" >&2
  exit 1
fi

otool -l "$BIN" | grep -q '__info_plist'
strings "$BIN" | grep -q 'NSCalendarsFullAccessUsageDescription'
strings "$BIN" | grep -q 'NSCalendarsUsageDescription'

echo "PASS release verification: $BIN"
