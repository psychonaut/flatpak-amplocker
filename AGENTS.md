# Amp Locker — Agent Notes

Flatpak repackaging of Audio Assault's proprietary "Amp Locker" guitar amp
suite. Upstream ships only a zip (`AmpLockerLinux.zip`) containing a
standalone binary, a VST3, an LV2 and a `AmpLockerData` tree (presets, cabs,
IRs, NAMs, `newgfx.dat`).

## Repository layout

| Path | Purpose |
| --- | --- |
| `AmpLockerLinux.zip` | Upstream binary blob (auto-downloaded from S3, cached locally; not in VCS, ~200 MB). All build inputs come from here. |
| `Justfile` | Task runner. Default (`just`) = flatpak build. `just flatpak-install` = build + install. `just flatpak-bundle` = build + create `.flatpak` single-file bundle. `just flatpak-run` = launch. Auto-downloads zip from S3 if missing, then extracts version and updates metainfo before building. |
| `mx.audioassault.amplocker.yml` | Flatpak manifest. App-id is `mx.audioassault.amplocker`. |
| `mx.audioassault.amplocker.metainfo.xml` | AppStream metadata (required for Flathub & to silence flatpak-builder). |
| `media/` | Shared assets pulled in by the flatpak build. |
| `media/mx.audioassault.amplocker.desktop` | Desktop entry; basename matches the app-id (required by Flatpak/Flathub). |
| `media/icons/{128,256,512}x*/apps/mx.audioassault.amplocker.png` | App icons. |
| `amplocker/` | Flatpak-builder working dir; contains unpacked zip contents during build. Disposable. |
| `.build/`, `builddir/`, `.flatpak-builder/` | Flatpak-builder outputs. Disposable. |
| `repo/` | Ostree repo created by `--repo=repo` (used by `flatpak-bundle`; disposable). |

## Upstream zip layout (after unpacking)

```
(zip root)
├── Amp Locker Standalone        # ELF binary (note spaces in name)
├── Amp Locker.vst3/Contents/... # VST3 bundle
├── Amp Locker.lv2/              # LV2 bundle (manifest.ttl, dsp.ttl, ui.ttl, *.so)
├── AmpLockerData/               # Presets, Cabs, IRs, NAMs, newgfx.dat
└── How To Install.txt           # User-facing readme; cleaned out at build time
```

The zip is full of `__MACOSX/` and `.DS_Store` cruft — every build path strips
those. Don't add new build steps that forget this.

## Runtime data path

Amp Locker looks for `AmpLockerData` at:

```
$HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData/
```

Note: directory name is `Audio Assault` (with a space), and the `Audio Assault`
segment appears **twice** in the path.

In the flatpak, `~/Audio Assault` is exposed via
`--filesystem=home/Audio Assault:create` and the bundled copy lives at
`/app/share/AmpLocker/AmpLockerData/`. On every launch the wrapper syncs
bundled data into the user's home with `cp -Ruf` (update-only: copies
only when source is newer), so upstream updates to presets, cabs, IRs,
NAMs, and `newgfx.dat` replace stale local copies without redundant I/O.

The app writes to four locations on a **native** install:

1. `~/Audio Assault/UserData/Amp Locker/` — preset library, `keys.ini`,
   `email.ini`, `subscription.ini`, `settings.ini`, `CabFileCache.dat`,
   `menuFavourites.dat`, etc. Licence key file lives here.
2. `~/.config/Amp Locker.settings` — JUCE `PropertiesFile` (window pos,
   audio device, filter/auth state, last preset, …). A **file** at the top
   level of `~/.config`, not a directory.
3. `~/.config/Amp Locker/` — `midi.ini`, `scenes.ini`.
4. `~/.config/Audio Assault/` — `UserData/Amp Locker/{email,keys,subscription}.ini`,
   `SimpleIRLoader/`, `Snapshots/`. Activation tokens live in this tree.

Locations 2–4 are the source of the "flatpak forgets last state" problem.
JUCE on Linux **hardcodes** `~/.config` for these paths — it does **not**
honour `$XDG_CONFIG_HOME` (verified by strace; setting the env var in a
wrapper had no effect on file destinations). So the only way to make these
persist is to expose `~/.config` itself.

Since flatpak cannot bind-mount a single file (location 2 is the file
`Amp Locker.settings` sitting at the root of `~/.config`), a per-subdir
mount strategy is insufficient. The manifest therefore uses
`--filesystem=xdg-config` (broad mount of `~/.config`) as the simplest
reliable fix. Trade-off: the proprietary app gets read/write to other
config dirs. Acceptable for now; revisit if upstream stops hardcoding
`~/.config` or if a wrapper-based copy-in/copy-out trick proves viable.

`AmpLockerData` is exposed via `--filesystem=home/Audio Assault:create`
(covering location 1 and the `PluginData/` tree) and the bundled copy lives
at `/app/share/AmpLocker/AmpLockerData/` for sync on every launch.

Things **not** to do (already tried, didn't work):
- Setting `--env=XDG_CONFIG_HOME=...`: ignored by JUCE for these paths.
- Wrapper that exports `XDG_CONFIG_HOME` before `exec`-ing the binary: same
  reason. Pulse cookie respects the env var; Amp Locker's settings do not.

## Version management

The version is stored in `mx.audioassault.amplocker.metainfo.xml` under
`<releases><release version="..."/>`. At build time, `just download-and-extract-version`
runs automatically (dependency of both `flatpak` and `flatpak-install`):

1. Downloads `AmpLockerLinux.zip` from S3 if not cached locally
   (`https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/AmpLockerLinux.zip`)
2. Reads `Amp Locker.vst3/Contents/Resources/moduleinfo.json` from the zip
   (contains `"Version": "1.5.2"` or similar)
3. Parses with `grep -o` + `cut` — **not** `jq`, the JSON has trailing commas
   that break `jq`
4. Replaces `<release version="...">` in metainfo.xml with `sed`

**Do not** use a broad `version=` regex in sed — it will corrupt
`<?xml version="1.0" encoding="UTF-8"?>`. Anchor on `<release version=`.

The local `AmpLockerLinux.zip` is kept as a cache for version extraction.
Delete it to force a re-download when checking for upstream updates:

```bash
rm AmpLockerLinux.zip
just flatpak
```

The date in the release tag should be updated manually when a new upstream
zip drops (match the zip's file modification date).

## Flatpak manifest gotchas

- App-id: `mx.audioassault.amplocker` (lowercase). Desktop file, icon names,
  and metainfo file basename **must** match this id.
- Runtime: `org.freedesktop.Platform//25.08`.
- `--share=network` is **required** — the app phones home for licence checks.
  Don't remove it.
- `--device=all` is currently kept (proprietary app, exact device needs unclear).
  `--device=dri` is probably enough but unverified.
- Plugins go to `/app/extensions/Plugins/{vst3,lv2}`. The standalone doesn't
  host third-party plugins, so do **not** re-add the
  `org.freedesktop.LinuxAudio.Plugins` `add-extensions` block (it was removed
  intentionally).
- Filenames with spaces: prefer double-quoted form (`"Amp Locker Standalone"`)
  over backslash-escaped (`Amp\ Locker\ Standalone`) in build-commands —
  flatpak-builder's shell parsing handles quotes more reliably.
- Filesystem syntax is `home/...:create`, **not** `~/...`. The tilde form is
  silently ignored in some flatpak versions.
- The upstream zip has **no top-level wrapper directory** (`Amp Locker.vst3/`,
  `Amp Locker.lv2/`, `AmpLockerData/` are all at the root of the archive).
  Flatpak-builder's `archive` source defaults to `strip-components: 1`, which
  silently destroys the bundle structure (turns `.vst3` and `.lv2` into loose
  files). The manifest **must** set `strip-components: 0` on this source.
- The zip is downloaded from S3 (`https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/AmpLockerLinux.zip`)
  with a verified SHA256 checksum. The manifest uses `url:` and `sha256:` for
  the archive source, not a local `path:`.

## Audio latency

The standalone is a JUCE app. The binary dlopens `libjack.so.0` and
`libasound.so.2` directly — it does **not** link PulseAudio. Both libs are
provided by `org.freedesktop.Platform//25.08`, so JACK and ALSA-direct
backends Just Work inside the sandbox.

One finish-arg is required for low-latency operation; without it the app
technically runs but xruns badly at small buffers:

```yaml
- --talk-name=org.freedesktop.RealtimeKit1
```

- **RTKit D-Bus name**: JUCE's audio thread asks RTKit for `SCHED_FIFO`.
  Inside flatpak that request silently fails unless the well-known name
  `org.freedesktop.RealtimeKit1` is reachable on the session bus. Symptom
  of missing it: xruns at any buffer size < ~512 frames even though the
  host machine has plenty of CPU headroom.

**Do NOT set `PIPEWIRE_LATENCY`** in the manifest. It looks like a free
latency win but it backfires: PipeWire's JACK shim reads the env var when
the client connects and reconfigures the *whole* graph to that quantum
for as long as Amp Locker is running. If the daemon's normal quantum is
larger than the requested one (1024 is a very common desktop default),
the forced drop causes crackling/xruns even with plenty of CPU headroom.
Native installs do not set this env var and let PipeWire stay at its
negotiated quantum — match that. The user can still pick a buffer size
in Amp Locker's Audio Settings dialog, or globally tighten the graph with
`pw-metadata 0 clock.force-quantum N` on the host.

`--socket=pulseaudio` is kept as a safety-net fallback. JUCE will prefer
JACK if the user picks it in the audio settings; otherwise it falls back
through ALSA → Pulse. Remove it only if forcing JACK/ALSA-direct
unconditionally is desired (and verify the app still produces audio).

The user must still pick **JACK** in Amp Locker's Audio Settings dialog —
the manifest can't choose the backend for them. ALSA-direct also works
(via `--device=all` exposing `/dev/snd`) but bypasses PipeWire, so other
apps lose audio while Amp Locker holds the device.

Things tried that don't help:
- `--env=JACK_NO_AUDIO_RESERVATION=1`: irrelevant, PipeWire's JACK shim
  ignores device reservation.
- Bumping `PIPEWIRE_QUANTUM` instead of `PIPEWIRE_LATENCY`: the former is
  the global daemon hint, the latter is per-client and is what JUCE/JACK
  apps actually pick up.

## Validation commands

```bash
# YAML sanity
python3 -c "import yaml; yaml.safe_load(open('mx.audioassault.amplocker.yml'))"

# Manifest parses
flatpak-builder --show-manifest mx.audioassault.amplocker.yml > /dev/null

# Metainfo
appstreamcli validate mx.audioassault.amplocker.metainfo.xml

# Full build
just flatpak
# equivalent to:
flatpak-builder --force-clean --user .build mx.audioassault.amplocker.yml
```

## Conventions for changes

- **Don't** edit anything inside `amplocker/`, `.build/`, `builddir/`,
  `.flatpak-builder/`, or `repo/` — they are regenerated.
- **Don't** commit `AmpLockerLinux.zip` (it's huge and licensed).
- When adding finish-args, prefer the most restrictive form that still works,
  but verify with the user before tightening — this is a proprietary app and
  failures are silent / mysterious.
- Shared assets (icons, desktop file) live in `media/`. Anything new that
  both packaging targets would have shared belongs there.
- Justfile recipes that use `$()` subshells must use a `#!/usr/bin/env bash`
  shebang — `just`'s `$$` escaping conflicts with `$()`, and `sh` may reject
  the syntax. With a shebang, write plain `$` (no escaping).
