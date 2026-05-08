#!/usr/bin/env bash
# CI-safe CLI JSON contract tests for calctl.
#
# Safety:
# - Uses a per-test temp HOME so the operator's real ~/.calctl is untouched.
# - Only exercises commands that either avoid EventKit entirely or fail in
#   pure validation before ensureEventAccess(). No TCC prompt should ever
#   appear from this script. No private Calendar data is read or written.
# - ArgumentParser usage failures (missing required options, etc.) are not
#   required to be JSON; this script only asserts JSON for runtime errors.
set -euo pipefail

cd "$(dirname "$0")/.."

CALCTL_BIN="${CALCTL_BIN:-.build/debug/calctl}"
if [[ ! -x "$CALCTL_BIN" ]]; then
    echo "Building calctl debug binary at $CALCTL_BIN"
    swift build --product calctl
fi
if [[ ! -x "$CALCTL_BIN" ]]; then
    echo "calctl binary not found at $CALCTL_BIN" >&2
    exit 1
fi
CALCTL_BIN_ABS="$(cd "$(dirname "$CALCTL_BIN")" && pwd)/$(basename "$CALCTL_BIN")"

TMP_HOME_ROOT="$(mktemp -d -t calctl-cli-tests-XXXXXX)"
trap 'rm -rf "$TMP_HOME_ROOT"' EXIT

PASSED=0
FAILED=0

# Run calctl with an isolated HOME and capture stdout/exit code.
# Usage: run_calctl <expected_exit> <stdout_var> <stderr_var> -- <args...>
run_calctl() {
    local expected_exit="$1"; shift
    local stdout_var="$1"; shift
    local stderr_var="$1"; shift
    [[ "$1" == "--" ]] || { echo "run_calctl: missing --"; return 2; }
    shift
    local home_dir
    home_dir="$(mktemp -d "$TMP_HOME_ROOT/home.XXXXXX")"
    local stdout_file stderr_file
    stdout_file="$(mktemp "$TMP_HOME_ROOT/stdout.XXXXXX")"
    stderr_file="$(mktemp "$TMP_HOME_ROOT/stderr.XXXXXX")"
    local actual_exit=0
    HOME="$home_dir" "$CALCTL_BIN_ABS" "$@" >"$stdout_file" 2>"$stderr_file" || actual_exit=$?
    if [[ "$actual_exit" -ne "$expected_exit" ]]; then
        echo "  exit mismatch: expected $expected_exit, got $actual_exit"
        echo "  stdout: $(cat "$stdout_file")"
        echo "  stderr: $(cat "$stderr_file")"
        return 1
    fi
    printf -v "$stdout_var" '%s' "$(cat "$stdout_file")"
    printf -v "$stderr_var" '%s' "$(cat "$stderr_file")"
    return 0
}

# Run calctl reusing a specific HOME (for sequential alias tests).
run_calctl_in_home() {
    local home_dir="$1"; shift
    local expected_exit="$1"; shift
    local stdout_var="$1"; shift
    local stderr_var="$1"; shift
    [[ "$1" == "--" ]] || { echo "run_calctl_in_home: missing --"; return 2; }
    shift
    local stdout_file stderr_file
    stdout_file="$(mktemp "$TMP_HOME_ROOT/stdout.XXXXXX")"
    stderr_file="$(mktemp "$TMP_HOME_ROOT/stderr.XXXXXX")"
    local actual_exit=0
    HOME="$home_dir" "$CALCTL_BIN_ABS" "$@" >"$stdout_file" 2>"$stderr_file" || actual_exit=$?
    if [[ "$actual_exit" -ne "$expected_exit" ]]; then
        echo "  exit mismatch: expected $expected_exit, got $actual_exit"
        echo "  stdout: $(cat "$stdout_file")"
        echo "  stderr: $(cat "$stderr_file")"
        return 1
    fi
    printf -v "$stdout_var" '%s' "$(cat "$stdout_file")"
    printf -v "$stderr_var" '%s' "$(cat "$stderr_file")"
    return 0
}

assert_json() {
    local label="$1"
    local payload="$2"
    shift 2
    if ! python3 - "$label" "$payload" "$@" <<'PY'
import json, sys
label = sys.argv[1]
payload = sys.argv[2]
checks = sys.argv[3:]
try:
    obj = json.loads(payload)
except json.JSONDecodeError as e:
    print(f"  not valid JSON: {e}")
    print(f"  payload: {payload!r}")
    sys.exit(1)
if not isinstance(obj, dict):
    print(f"  expected JSON object, got {type(obj).__name__}")
    sys.exit(1)
for spec in checks:
    if "=" in spec:
        key, expected = spec.split("=", 1)
        actual = obj.get(key)
        if str(actual) != expected:
            print(f"  field {key} expected {expected!r}, got {actual!r}")
            sys.exit(1)
    elif spec.startswith("contains:"):
        _, key, needle = spec.split(":", 2)
        actual = obj.get(key)
        if not isinstance(actual, str) or needle not in actual:
            print(f"  field {key} expected to contain {needle!r}, got {actual!r}")
            sys.exit(1)
    elif spec.startswith("has:"):
        key = spec.split(":", 1)[1]
        if key not in obj:
            print(f"  expected key {key!r} present")
            sys.exit(1)
    elif spec.startswith("type:"):
        _, key, type_name = spec.split(":", 2)
        actual = obj.get(key)
        type_map = {
            "list": list,
            "dict": dict,
            "str": str,
            "int": int,
            "bool": bool,
        }
        if not isinstance(actual, type_map[type_name]):
            print(f"  field {key} expected type {type_name}, got {type(actual).__name__}")
            sys.exit(1)
    else:
        print(f"  unknown spec {spec!r}")
        sys.exit(1)
PY
    then
        return 1
    fi
    return 0
}

run_test() {
    local name="$1"
    shift
    if "$@"; then
        echo "PASS $name"
        PASSED=$((PASSED+1))
    else
        echo "FAIL $name"
        FAILED=$((FAILED+1))
    fi
}

# --- Tests ---

test_auth_status_json() {
    local out err
    run_calctl 0 out err -- auth status || return 1
    assert_json "auth status" "$out" "status=success" "entity=event" "has:authorizationStatus" || return 1
}

test_alias_list_initial_empty() {
    local out err
    run_calctl 0 out err -- alias list || return 1
    assert_json "alias list initial" "$out" "status=success" "type:aliases:list" "count=0" "has:configPath" || return 1
}

test_alias_set_list_remove_lifecycle() {
    local home_dir
    home_dir="$(mktemp -d "$TMP_HOME_ROOT/home.XXXXXX")"
    local out err
    run_calctl_in_home "$home_dir" 0 out err -- alias set testcal CALENDAR-ID-123 || return 1
    assert_json "alias set" "$out" "status=success" "has:alias" "has:configPath" || return 1
    run_calctl_in_home "$home_dir" 0 out err -- alias list || return 1
    assert_json "alias list populated" "$out" "status=success" "count=1" || return 1
    if ! python3 - "$out" <<'PY'
import json, sys
obj = json.loads(sys.argv[1])
aliases = obj["aliases"]
if not (isinstance(aliases, list) and len(aliases) == 1):
    sys.exit(f"expected one alias, got {aliases!r}")
entry = aliases[0]
if entry.get("name") != "testcal" or entry.get("id") != "CALENDAR-ID-123":
    sys.exit(f"unexpected alias entry: {entry!r}")
PY
    then
        echo "  alias entry mismatch"
        return 1
    fi
    run_calctl_in_home "$home_dir" 0 out err -- alias remove testcal || return 1
    assert_json "alias remove" "$out" "status=success" "has:message" || return 1
    run_calctl_in_home "$home_dir" 0 out err -- alias list || return 1
    assert_json "alias list after remove" "$out" "status=success" "count=0" || return 1
}

test_alias_set_bad_name_errors_json() {
    local out err
    run_calctl 1 out err -- alias set 'bad/name' CALENDAR-ID-123 || return 1
    assert_json "alias set bad name" "$out" "status=error" "has:error" || return 1
}

test_alias_remove_missing_errors_json() {
    local out err
    run_calctl 1 out err -- alias remove never-existed || return 1
    assert_json "alias remove missing" "$out" "status=error" "contains:error:Alias not found" || return 1
}

test_defaults_show_and_alerts_lifecycle() {
    local home_dir
    home_dir="$(mktemp -d "$TMP_HOME_ROOT/home.XXXXXX")"
    local out err
    run_calctl_in_home "$home_dir" 0 out err -- defaults show || return 1
    assert_json "defaults show initial" "$out" "status=success" "type:defaultAlertMinutes:list" "has:configPath" || return 1
    if ! python3 - "$out" <<'PY'
import json, sys
obj = json.loads(sys.argv[1])
if obj.get("defaultAlertMinutes") != [1440, 120]:
    sys.exit(f"unexpected initial defaults: {obj.get('defaultAlertMinutes')!r}")
PY
    then
        echo "  initial defaults mismatch"
        return 1
    fi
    run_calctl_in_home "$home_dir" 0 out err -- defaults alerts --minutes 60 --minutes 10 --minutes 60 || return 1
    assert_json "defaults alerts set" "$out" "status=success" "has:message" "type:defaultAlertMinutes:list" || return 1
    if ! python3 - "$out" <<'PY'
import json, sys
obj = json.loads(sys.argv[1])
if obj.get("defaultAlertMinutes") != [60, 10]:
    sys.exit(f"unexpected updated defaults: {obj.get('defaultAlertMinutes')!r}")
PY
    then
        echo "  updated defaults mismatch"
        return 1
    fi
    run_calctl_in_home "$home_dir" 0 out err -- defaults reset-alerts || return 1
    assert_json "defaults alerts reset" "$out" "status=success" "has:message" "type:defaultAlertMinutes:list" || return 1
}

test_defaults_alerts_bad_value_errors_json() {
    local out err
    run_calctl 1 out err -- defaults alerts --minutes 525601 || return 1
    assert_json "defaults alerts bad value" "$out" "status=error" "has:error" || return 1
}

test_create_without_force_fails_before_eventkit() {
    local out err
    run_calctl 1 out err -- events create --title "No Force" --start 2026-05-08T09:00:00Z --end 2026-05-08T10:00:00Z || return 1
    assert_json "events create without --force" "$out" "status=error" "contains:error:without --force" || return 1
}

test_update_without_force_fails_before_eventkit() {
    local out err
    run_calctl 1 out err -- events update FAKE-ID --title "X" || return 1
    assert_json "events update without --force" "$out" "status=error" "contains:error:without --force" || return 1
}

test_delete_without_force_fails_before_eventkit() {
    local out err
    run_calctl 1 out err -- events delete FAKE-ID || return 1
    assert_json "events delete without --force" "$out" "status=error" "contains:error:without --force" || return 1
}

test_create_invalid_alldate_fails_pure_validation() {
    # --force present so requireForce passes; invalid all-day date fails in
    # EventPreflight.validateCreate before ensureEventAccess().
    local out err
    run_calctl 1 out err -- events create --title "Bad Date" --date 2026-13-01 --force || return 1
    assert_json "events create invalid date" "$out" "status=error" "has:error" || return 1
}

test_create_invalid_url_fails_pure_validation() {
    local out err
    run_calctl 1 out err -- events create --title "Bad URL" --start 2026-05-08T09:00:00Z --end 2026-05-08T10:00:00Z --url "not a url" --force || return 1
    assert_json "events create invalid url" "$out" "status=error" "has:error" || return 1
}

test_create_alarm_out_of_range_fails_pure_validation() {
    local out err
    run_calctl 1 out err -- events create --title "Bad Alarm" --start 2026-05-08T09:00:00Z --end 2026-05-08T10:00:00Z --alarm-minutes 525601 --force || return 1
    assert_json "events create alarm out of range" "$out" "status=error" "has:error" || return 1
}

test_create_structured_location_validation_fails_before_eventkit() {
    local out err
    run_calctl 1 out err -- events create --title "Bad Location" --start 2026-05-08T09:00:00Z --end 2026-05-08T10:00:00Z --structured-location-title "Office" --latitude 40 --force || return 1
    assert_json "events create incomplete structured location" "$out" "status=error" "contains:error:latitude" || return 1
    run_calctl 1 out err -- events create --title "Bad Location" --start 2026-05-08T09:00:00Z --end 2026-05-08T10:00:00Z --structured-location-title "Office" --latitude 91 --longitude 0 --force || return 1
    assert_json "events create invalid structured latitude" "$out" "status=error" "contains:error:latitude" || return 1
}

test_update_no_fields_fails_pure_validation() {
    local out err
    run_calctl 1 out err -- events update FAKE-ID --force || return 1
    assert_json "events update no fields" "$out" "status=error" "has:error" || return 1
}

test_update_bad_span_fails_pure_validation() {
    local out err
    run_calctl 1 out err -- events update FAKE-ID --title "X" --span all --force || return 1
    assert_json "events update bad span" "$out" "status=error" "contains:error:Span" || return 1
}

test_delete_bad_span_fails_pure_validation() {
    local out err
    run_calctl 1 out err -- events delete FAKE-ID --span all --force || return 1
    assert_json "events delete bad span" "$out" "status=error" "contains:error:Span" || return 1
}

test_update_clear_and_set_fails_pure_validation() {
    local out err
    run_calctl 1 out err -- events update FAKE-ID --location "Room" --clear-location --force || return 1
    assert_json "events update conflicting flags" "$out" "status=error" "has:error" || return 1
}

run_test "auth status returns JSON success"               test_auth_status_json
run_test "alias list returns empty in fresh HOME"         test_alias_list_initial_empty
run_test "alias set/list/remove lifecycle"                test_alias_set_list_remove_lifecycle
run_test "alias set rejects bad name with JSON error"     test_alias_set_bad_name_errors_json
run_test "alias remove missing emits JSON error"          test_alias_remove_missing_errors_json
run_test "defaults show/set/reset lifecycle"              test_defaults_show_and_alerts_lifecycle
run_test "defaults alerts bad value emits JSON error"     test_defaults_alerts_bad_value_errors_json
run_test "events create without --force fails as JSON"    test_create_without_force_fails_before_eventkit
run_test "events update without --force fails as JSON"    test_update_without_force_fails_before_eventkit
run_test "events delete without --force fails as JSON"    test_delete_without_force_fails_before_eventkit
run_test "events create invalid all-day date pure-fails"  test_create_invalid_alldate_fails_pure_validation
run_test "events create invalid URL pure-fails"           test_create_invalid_url_fails_pure_validation
run_test "events create alarm out of range pure-fails"    test_create_alarm_out_of_range_fails_pure_validation
run_test "events create structured location pure-fails"   test_create_structured_location_validation_fails_before_eventkit
run_test "events update no fields pure-fails"             test_update_no_fields_fails_pure_validation
run_test "events update bad span pure-fails"              test_update_bad_span_fails_pure_validation
run_test "events delete bad span pure-fails"              test_delete_bad_span_fails_pure_validation
run_test "events update clear+set conflict pure-fails"    test_update_clear_and_set_fails_pure_validation

echo
if [[ "$FAILED" -gt 0 ]]; then
    echo "FAILED $FAILED, passed $PASSED"
    exit 1
fi
echo "PASSED $PASSED CLI JSON tests"
