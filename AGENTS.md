# Amp Locker — Agent Notes

Flatpak repackaging of Audio Assault's proprietary "Amp Locker" guitar amp
suite. Upstream ships only a zip (`AmpLockerLinux.zip`) containing a
standalone binary, a VST3, an LV2 and a `AmpLockerData` tree (presets, cabs,
IRs, NAMs, `newgfx.dat`).

## Repository layout

| Path | Purpose |
| --- | --- |
| `AmpLockerLinux.zip` | Upstream binary blob (not in VCS, ~200 MB). All build inputs come from here. |
| `Justfile` | Task runner. `just build` = clean + unzip + rsync into `~/Audio Assault` (for native testing). `just flatpak` = build the flatpak. |
| `mx.audioassault.amplocker.yml` | Flatpak manifest. App-id is `mx.audioassault.amplocker`. |
| `mx.audioassault.amplocker.metainfo.xml` | AppStream metadata (required for Flathub & to silence flatpak-builder). |
| `media/` | Shared assets pulled in by the flatpak build. |
| `media/mx.audioassault.amplocker.desktop` | Desktop entry; basename matches the app-id (required by Flatpak/Flathub). |
| `media/icons/{128,256,512}x*/apps/mx.audioassault.amplocker.png` | App icons. |
| `amplocker/` | Working dir created by `just unzip`; contains the unpacked upstream tree. Disposable. |
| `.build/`, `builddir/`, `.flatpak-builder/`, `repo/` | Flatpak-builder outputs. Disposable. |

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
segment appears **twice** in the path. The Justfile's `rsync` target writes to
`AudioAssault` (no space) inside `PluginData/` — that mismatch is a known bug;
verify with the user before "fixing" it (they may rely on the legacy path).

In the flatpak, `~/Audio Assault` is exposed via
`--filesystem=home/Audio Assault:create` and the bundled copy lives at
`/app/share/AmpLocker/AmpLockerData/` for first-run sync.

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
at `/app/share/AmpLocker/AmpLockerData/` for first-run sync.

Things **not** to do (already tried, didn't work):
- Setting `--env=XDG_CONFIG_HOME=...`: ignored by JUCE for these paths.
- Wrapper that exports `XDG_CONFIG_HOME` before `exec`-ing the binary: same
  reason. Pulse cookie respects the env var; Amp Locker's settings do not.

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
- The `AmpLockerLinux.zip` source path is relative to the manifest's directory.
  Don't hardcode absolute paths there.

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
