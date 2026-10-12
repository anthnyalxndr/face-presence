# face-presence

A macOS command-line tool that answers one question: is someone in front of the camera?

It opens the built-in camera, takes one frame into memory, counts faces with Apple's
on-device Vision framework, closes the camera, and prints a JSON line. The frame is
released as soon as the detector returns. Nothing is written to disk and nothing
leaves the machine. Because the camera is opened and closed around each sample, the
indicator light is on for well under a second per sample.

```
$ face-presence --once
{"timestamp":"2026-10-12T21:39:29Z","present":true,"faces":1}
```

Built for presence detection in time trackers (the input-based idle detectors miss
people who are reading or thinking), but it has no opinion about what you do with
the output.

## Install

Requires macOS 12 or later and the Xcode command-line tools (`xcode-select --install`).

```bash
make install            # builds and copies to ~/.local/bin/face-presence
make install PREFIX=/usr/local
```

The first run asks for camera permission. The binary is ad-hoc signed with a stable
identifier so the grant survives rebuilds. If you run it under launchd, grant the
permission by running it once in a terminal first.

## Usage

```
face-presence [--once] [--interval SECONDS] [--timeout SECONDS]

  --once       take one sample, print it, exit
  --interval   seconds between samples in loop mode (default 60)
  --timeout    seconds to wait for a usable frame (default 4)
```

Loop mode prints one line per sample to stdout and never buffers, so it pipes
cleanly into whatever consumes it:

```bash
face-presence --interval 30 | while read -r line; do curl -s -X POST ... -d "$line"; done
```

Exit codes: 0 ok, 2 camera permission denied, 3 no camera found, 64 bad usage.
Errors go to stderr; stdout only ever carries JSON lines.

## Limits

Face detection, not face recognition: any face counts, including one on a screen
behind you. It misses you when you lean out of frame or the lid is angled away, and
it has nothing to look at in clamshell mode. The first few frames after opening the
camera are skipped so auto-exposure can settle, which is why a sample takes about
half a second rather than a few milliseconds.

## Development

```bash
make check                              # typecheck and CLI tests, no camera needed
FACE_PRESENCE_CAMERA_TEST=1 make check  # also takes one real sample
```

See [AGENTS.md](./AGENTS.md) for conventions.

## Template

Scaffolded from [`anthnyalxndr/copier-templates`](https://github.com/anthnyalxndr/copier-templates).
Pull future template improvements into this repo with:

```bash
uvx copier update
```
