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
- `just` (task runner) — optional but recommended
- `unzip`, `rsync`
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
| `just flatpak`       | Build only (no install). Output in `.build/`.            |
| `just build`         | Native-install path: unzip + rsync data into `~/Audio Assault`. Useful for testing without Flatpak. |
| `just unzip`         | Just unpack the zip into `amplocker/` and clean cruft.   |
| `just clean`         | Remove the `amplocker/` working dir.                     |

## What's in the box

- **Standalone**: `mx.audioassault.amplocker` (renamed from `Amp Locker Standalone`)
- **VST3**: installed to `/app/extensions/Plugins/vst3/Amp Locker.vst3`
- **LV2**: installed to `/app/extensions/Plugins/lv2/Amp Locker.lv2`
- **Bundled data** (presets, cabs, IRs, NAMs, `newgfx.dat`): seeded from
  `/app/share/AmpLocker/AmpLockerData/`

## Runtime data layout

Amp Locker looks for its preset/IR/NAM tree at:

```
~/Audio Assault/PluginData/Audio Assault/AmpLockerData/
```

(Yes, the `Audio Assault` segment appears twice — that's upstream behaviour.)

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
| `media/icons/{128,256,512}x*/apps/*.png`   | Application icons                                    |
| `Justfile`                                 | Task runner                                          |
| `AGENTS.md`                                | Detailed packaging notes, gotchas, validation tips   |
| `AmpLockerLinux.zip`                       | Upstream blob (you provide; **not** in VCS)          |

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
