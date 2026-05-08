#!/usr/bin/env bash
# Opt-in local EventKit E2E test for calctl.
#
# This script intentionally is NOT CI-safe and must not run automatically. It
# writes only to an existing writable calendar named exactly "CalCTL Test" and
# deletes the synthetic events it creates.
set -euo pipefail

cd "$(dirname "$0")/.."

APPROVAL_VALUE="I_UNDERSTAND_CALCTL_TEST_ONLY"
if [[ "${CALCTL_E2E_APPROVED:-}" != "$APPROVAL_VALUE" ]]; then
  cat >&2 <<MSG
Refusing to run Calendar E2E writes.

This script creates and deletes synthetic events in an existing writable calendar
named exactly "CalCTL Test". To run locally after reviewing the script:

  CALCTL_E2E_APPROVED=$APPROVAL_VALUE scripts/test-e2e-calendar.sh

MSG
  exit 2
fi

CALCTL_BIN="${CALCTL_BIN:-.build/debug/calctl}"
if [[ ! -x "$CALCTL_BIN" ]]; then
  swift build --product calctl
fi
CALCTL_BIN_ABS="$(cd "$(dirname "$CALCTL_BIN")" && pwd)/$(basename "$CALCTL_BIN")"

TMP_HOME="$(mktemp -d -t calctl-e2e-home-XXXXXX)"
TMP_FILES="$(mktemp -d -t calctl-e2e-files-XXXXXX)"
CREATED_IDS=()
CAL_ID=""
TIMED_TITLE=""
TIMED_UPDATED_TITLE=""
ALLDAY_TITLE=""
fallback_delete_by_title() {
  local title="$1"
  local from="$2"
  local to="$3"
  [[ -n "$title" && -n "$CAL_ID" ]] || return 0
  local list_file ids_file id
  list_file="$(mktemp "$TMP_FILES/cleanup-list.XXXXXX")"
  ids_file="$(mktemp "$TMP_FILES/cleanup-ids.XXXXXX")"
  HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events list --calendar "$CAL_ID" --from "$from" --to "$to" > "$list_file" 2>/dev/null || return 0
  python3 - "$list_file" "$title" > "$ids_file" <<'PY' || return 0
import json, sys
obj=json.load(open(sys.argv[1]))
title=sys.argv[2]
for event in obj.get('events', []):
    if event.get('title') == title and str(title).startswith('CalCTL E2E'):
        event_id = event.get('id')
        if event_id:
            print(event_id)
PY
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events delete "$id" --span this --force >/dev/null 2>&1 || true
  done < "$ids_file"
}
cleanup() {
  local id
  for id in "${CREATED_IDS[@]:-}"; do
    if [[ -n "$id" ]]; then
      HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events delete "$id" --span this --force >/dev/null 2>&1 || true
    fi
  done
  fallback_delete_by_title "$TIMED_TITLE" 2026-05-08T00:00:00Z 2026-05-09T00:00:00Z
  fallback_delete_by_title "$TIMED_UPDATED_TITLE" 2026-05-08T00:00:00Z 2026-05-09T00:00:00Z
  fallback_delete_by_title "$ALLDAY_TITLE" 2026-05-09T00:00:00Z 2026-05-10T00:00:00Z
  rm -rf "$TMP_HOME" "$TMP_FILES"
}
trap cleanup EXIT

json_file() {
  local file="$1"; shift
  HOME="$TMP_HOME" "$CALCTL_BIN_ABS" "$@" > "$file"
  python3 -m json.tool "$file" >/dev/null
}

json_file "$TMP_FILES/auth.json" auth status
python3 - "$TMP_FILES/auth.json" <<'PY'
import json, sys
status = json.load(open(sys.argv[1])).get('authorizationStatus')
if status not in {'authorized', 'fullAccess'}:
    raise SystemExit(f'Calendar full access required before E2E run; auth status is {status!r}')
print('Calendar access: ready')
PY

json_file "$TMP_FILES/calendars.json" calendars list --writable-only
CAL_ID="$(python3 - "$TMP_FILES/calendars.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
matches=[c for c in obj.get('calendars', []) if c.get('title') == 'CalCTL Test' and c.get('allowsModifications') is True]
print(matches[0]['id'] if len(matches) == 1 else '')
PY
)"
if [[ -z "$CAL_ID" ]]; then
  echo "Disposable calendar found: no" >&2
  echo "Create one writable calendar titled exactly 'CalCTL Test' and retry." >&2
  exit 2
fi
echo "Disposable calendar found: yes"

if [[ "${CALCTL_E2E_NONINTERACTIVE:-}" != "$APPROVAL_VALUE" ]]; then
  printf 'About to create/delete synthetic CalCTL E2E events only in CalCTL Test. Type YES to continue: ' >&2
  read -r answer
  if [[ "$answer" != "YES" ]]; then
    echo "Aborted." >&2
    exit 2
  fi
fi

HOME="$TMP_HOME" "$CALCTL_BIN_ABS" alias set test "$CAL_ID" > "$TMP_FILES/alias-set.json"
python3 -m json.tool "$TMP_FILES/alias-set.json" >/dev/null
HOME="$TMP_HOME" "$CALCTL_BIN_ABS" alias list > "$TMP_FILES/alias-list.json"
python3 -m json.tool "$TMP_FILES/alias-list.json" >/dev/null

TIMED_TITLE="CalCTL E2E timed $(date +%Y%m%d%H%M%S)"
HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events create --calendar test --title "$TIMED_TITLE" --start 2026-05-08T09:00:00Z --end 2026-05-08T10:00:00Z --notes "CalCTL E2E synthetic note" --force > "$TMP_FILES/create-timed.json"
python3 -m json.tool "$TMP_FILES/create-timed.json" >/dev/null
TIMED_ID="$(python3 - "$TMP_FILES/create-timed.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
print(obj.get('event', {}).get('id',''))
PY
)"
[[ -n "$TIMED_ID" ]] || { echo "Timed event ID missing" >&2; exit 1; }
CREATED_IDS+=("$TIMED_ID")
python3 - "$TMP_FILES/create-timed.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
event=obj.get('event', {})
if 'notes' in event:
    raise SystemExit('create response unexpectedly included notes')
PY

HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events list --calendar test --from 2026-05-08T00:00:00Z --to 2026-05-09T00:00:00Z > "$TMP_FILES/list.json"
python3 - "$TMP_FILES/list.json" <<'PY'
import json, sys
obj=json.load(open(sys.argv[1]))
for event in obj.get('events', []):
    if 'notes' in event:
        raise SystemExit('list response unexpectedly included notes')
PY

HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events show "$TIMED_ID" > "$TMP_FILES/show-no-notes.json"
python3 - "$TMP_FILES/show-no-notes.json" <<'PY'
import json, sys
if 'notes' in json.load(open(sys.argv[1])).get('event', {}):
    raise SystemExit('show response unexpectedly included notes without --include-notes')
PY

HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events show "$TIMED_ID" --include-notes > "$TMP_FILES/show-notes.json"
python3 - "$TMP_FILES/show-notes.json" <<'PY'
import json, sys
if 'notes' not in json.load(open(sys.argv[1])).get('event', {}):
    raise SystemExit('show --include-notes response missing notes')
PY

TIMED_UPDATED_TITLE="$TIMED_TITLE updated"
HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events update "$TIMED_ID" --title "$TIMED_UPDATED_TITLE" --force > "$TMP_FILES/update.json"
python3 - "$TMP_FILES/update.json" <<'PY'
import json, sys
if 'notes' in json.load(open(sys.argv[1])).get('event', {}):
    raise SystemExit('update response unexpectedly included notes')
PY

HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events delete "$TIMED_ID" --span this --force > "$TMP_FILES/delete-timed.json"
python3 -m json.tool "$TMP_FILES/delete-timed.json" >/dev/null
CREATED_IDS=()

ALLDAY_TITLE="CalCTL E2E all-day $(date +%Y%m%d%H%M%S)"
HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events create --calendar test --title "$ALLDAY_TITLE" --date 2026-05-09 --force > "$TMP_FILES/create-allday.json"
python3 -m json.tool "$TMP_FILES/create-allday.json" >/dev/null
ALLDAY_ID="$(python3 - "$TMP_FILES/create-allday.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get('event', {}).get('id',''))
PY
)"
[[ -n "$ALLDAY_ID" ]] || { echo "All-day event ID missing" >&2; exit 1; }
CREATED_IDS+=("$ALLDAY_ID")
HOME="$TMP_HOME" "$CALCTL_BIN_ABS" events delete "$ALLDAY_ID" --span this --force > "$TMP_FILES/delete-allday.json"
python3 -m json.tool "$TMP_FILES/delete-allday.json" >/dev/null
CREATED_IDS=()

echo "PASS local Calendar E2E against disposable CalCTL Test calendar"
