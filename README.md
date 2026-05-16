# flatpak-amplocker

Unofficial Flatpak packaging for [Audio Assault](https://audioassault.mx/)'s
proprietary **Amp Locker** guitar tone suite (standalone + VST3 + LV2).

> This repository contains **only packaging** — no proprietary code or assets.
> You must supply your own `AmpLockerLinux.zip` from Audio Assault. A valid
> Amp Locker licence is required at runtime; the app phones home for
> activation.

App-id: `mx.audioassault.amplocker`

## Requirements

- `flatpak`, `flatpak-builder`
- [`just`](https://github.com/casey/just) (task runner) — optional but recommended
- The upstream `AmpLockerLinux.zip` placed at the repo root (not redistributed
  here)
- Freedesktop runtime: `org.freedesktop.Platform//25.08` and matching SDK
  (installed automatically by `flatpak-builder` on first build)

## Build & install

```sh
# Build and install into the user flatpak installation
just flatpak-install

# Run it
just flatpak-run
# or:
flatpak run mx.audioassault.amplocker
```

Other targets:

| Command              | Description                                              |
| -------------------- | -------------------------------------------------------- |
| `just flatpak`       | Build only (no install). Output in `.build/` + `repo/`. |
| `just flatpak-install` | Build and install into user flatpak installation.      |
| `just flatpak-bundle` | Build and create a versioned `.flatpak` single-file bundle for distribution. |
| `just flatpak-run`   | Launch the installed flatpak.                            |
| `just extract-version` | Extract version from zip and update metainfo.xml. Runs automatically before builds. |

## What's in the box

- **Launcher**: `/app/bin/mx.audioassault.amplocker` — a small shell wrapper
  (`media/amplocker-wrapper.sh`) that seeds bundled data into the user's home
  before `exec`-ing the real binary.
- **Standalone binary**: `/app/libexec/amplocker` (originally `Amp Locker Standalone`)
- **VST3**: installed to `/app/extensions/Plugins/vst3/Amp Locker.vst3`
- **LV2**: installed to `/app/extensions/Plugins/lv2/Amp Locker.lv2`
- **Bundled data** (presets, cabs, IRs, NAMs, `newgfx.dat`): shipped read-only
  at `/app/share/AmpLocker/AmpLockerData/` and topped up into the user's home
  on every launch.

## Runtime data layout

Amp Locker looks for its preset/IR/NAM tree at:

```
~/Audio Assault/PluginData/Audio Assault/AmpLockerData/
```

(Yes, the `Audio Assault` segment appears twice — that's upstream behaviour.)

### First-run seeding

On every launch the wrapper does:

```sh
cp -Rn /app/share/AmpLocker/AmpLockerData/. \
       "$HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData/"
```

`-n` (no-clobber) means:

- **First launch**: the full bundled tree (~177 MB, ~700 files) is copied
  into the user's home.
- **Subsequent launches**: only files that don't already exist are copied.
  Your edits to bundled presets and any extra presets/IRs you've added are
  preserved.
- **Caveat**: deleting a bundled file makes it reappear on the next launch.
  This is the deliberate trade-off of the "always top-up" strategy (vs. a
  one-shot sentinel marker), so that new presets/IRs that ship with future
  upstream releases land automatically.

JUCE on Linux hardcodes `~/.config` for `PropertiesFile` /
`userApplicationDataDirectory` paths, so the manifest mounts the whole
`xdg-config` directory. State written there:

- `~/.config/Amp Locker.settings` — window / audio device / last preset
- `~/.config/Amp Locker/` — `midi.ini`, `scenes.ini`
- `~/.config/Audio Assault/` — activation tokens, snapshots, IR loader state
- `~/Audio Assault/UserData/Amp Locker/` — preset library, `keys.ini`, etc.

## Audio backends

The bundled binary `dlopen`s `libjack.so.0` and `libasound.so.2` directly; it
does not link PulseAudio. Inside the sandbox:

- **JACK** (PipeWire's JACK shim) — recommended, lowest latency. Select it in
  Amp Locker's Audio Settings dialog.
- **ALSA-direct** — works via `--device=all`, but holds the device
  exclusively.
- **PulseAudio** — kept as a fallback (`--socket=pulseaudio`).

For low-latency operation, the manifest exposes
`org.freedesktop.RealtimeKit1` on the session bus so JUCE can obtain
`SCHED_FIFO`. `PIPEWIRE_LATENCY` is **intentionally not set** — see comments
in the manifest and `AGENTS.md` for the rationale.

## Repository layout

| Path                                       | Purpose                                              |
| ------------------------------------------ | ---------------------------------------------------- |
| `mx.audioassault.amplocker.yml`            | Flatpak manifest                                     |
| `mx.audioassault.amplocker.metainfo.xml`   | AppStream metadata                                   |
| `media/mx.audioassault.amplocker.desktop`  | Desktop entry                                        |
| `media/amplocker-wrapper.sh`               | Launcher: seeds `AmpLockerData` into home, then execs the binary |
| `media/icons/{128,256,512}x*/apps/*.png`   | Application icons                                    |
| `Justfile`                                 | Task runner. Default = flatpak build. Version auto-extracted from zip. |
| `AGENTS.md`                                | Detailed packaging notes, gotchas, validation tips   |
| `AmpLockerLinux.zip`                       | Upstream blob (you provide; **not** in VCS)          |
| `repo/`                                    | Flatpak ostree repo (created by `--repo=repo`; disposable) |
| `*.flatpak`                                | Single-file distribution bundle (generated by `flatpak-bundle`; **not** in VCS) |

`AGENTS.md` is the authoritative reference for everything packaging-related,
including things already tried that don't work.

## Validation

```sh
# YAML sanity
python3 -c "import yaml; yaml.safe_load(open('mx.audioassault.amplocker.yml'))"

# Manifest parses
flatpak-builder --show-manifest mx.audioassault.amplocker.yml > /dev/null

# AppStream metadata
appstreamcli validate mx.audioassault.amplocker.metainfo.xml
```

## Licence

Packaging files (manifest, Justfile, metainfo, desktop entry, icons in this
repo) are provided under the same terms as the rest of the repository.

**Amp Locker itself is proprietary software © Audio Assault.** This
repository neither contains nor redistributes it. You must obtain
`AmpLockerLinux.zip` and a valid licence directly from Audio Assault.

This project is not affiliated with or endorsed by Audio Assault.
