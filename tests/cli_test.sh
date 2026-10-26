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
expect64 --dark-threshold
expect64 --dark-threshold 2
expect64 --dark-threshold abc

usage_text=$("$BIN" --help 2>&1 >/dev/null || true)
case "$usage_text" in *"usage: face-presence"*) ;; *) fail "usage text missing" ;; esac

# Camera-backed smoke test, only when explicitly requested (needs a camera and
# the permission grant): one sample must be a JSON object with the three keys.
if [ "${FACE_PRESENCE_CAMERA_TEST:-}" = "1" ]; then
  line=$("$BIN" --once) || fail "--once exited $?"
  echo "$line" | python3 -I -c '
import json, sys
d = json.loads(sys.stdin.read())
assert set(d) == {"timestamp", "present", "faces", "luminance", "dark"}, d
assert isinstance(d["faces"], int) and isinstance(d["dark"], bool), d
assert 0 <= d["luminance"] <= 1, d
if d["dark"]:
    assert d["present"] is None, d
else:
    assert isinstance(d["present"], bool) and d["present"] == (d["faces"] > 0), d
print("camera sample ok:", d)
' || fail "camera sample malformed"

  # Loop mode must reuse one capture session. AVFoundation never frees a
  # session that has run, and each leaked one makes every later sample slower
  # and larger. Count live sessions with heap(1) after several fast samples.
  out=$(mktemp)
  "$BIN" --interval 0.5 >"$out" 2>/dev/null &
  pid=$!
  sleep 15
  sessions=$(heap "$pid" 2>/dev/null | awk '$4 ~ /^(NSKVONotifying_)?AVCaptureSession(_Tundra)?$/ {n += $1} END {print n + 0}')
  kill "$pid"
  samples=$(wc -l <"$out" | tr -d ' ')
  rm -f "$out"
  [ "$samples" -ge 5 ] || fail "loop mode printed $samples samples in 15s, want at least 5"
  [ "$sessions" -le 2 ] || fail "$sessions capture sessions alive after $samples samples, want at most 2"
  echo "loop sample ok: $samples samples, $sessions live capture sessions"
fi
echo "ok: cli tests"
