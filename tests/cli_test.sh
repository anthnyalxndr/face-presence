#!/usr/bin/env bash
# Argument-handling tests. These exercise everything that runs before the
# camera is touched, so they pass on machines (and CI runners) without one.
set -uo pipefail
BIN="${1:?usage: cli_test.sh path/to/face-presence}"
fail() { echo "FAIL: $*" >&2; exit 1; }

expect64() {
  "$BIN" "$@" >/dev/null 2>&1
  [ $? -eq 64 ] || fail "'$*' should exit 64"
}
expect64 --bogus
expect64 --interval
expect64 --interval 0
expect64 --interval abc
expect64 --timeout abc
expect64 --help

usage_text=$("$BIN" --help 2>&1 >/dev/null || true)
case "$usage_text" in *"usage: face-presence"*) ;; *) fail "usage text missing" ;; esac

# Camera-backed smoke test, only when explicitly requested (needs a camera and
# the permission grant): one sample must be a JSON object with the three keys.
if [ "${FACE_PRESENCE_CAMERA_TEST:-}" = "1" ]; then
  line=$("$BIN" --once) || fail "--once exited $?"
  echo "$line" | python3 -I -c '
import json, sys
d = json.loads(sys.stdin.read())
assert set(d) == {"timestamp", "present", "faces"}, d
assert isinstance(d["present"], bool) and isinstance(d["faces"], int), d
assert d["present"] == (d["faces"] > 0), d
print("camera sample ok:", d)
' || fail "camera sample malformed"
fi
echo "ok: cli tests"
