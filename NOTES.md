# Session Notes & Observations

## Version 1.5.5 Upgrade (2026-08-16)

### Successful Update Workflow
1. ✅ Removed old `AmpLockerLinux.zip` to force re-download
2. ✅ Downloaded v1.5.5 from S3 (227.5 MB)
3. ✅ Extracted version from `Amp Locker.vst3/Contents/Resources/moduleinfo.json`
4. ✅ Calculated new SHA256: `2d229fe96112aff59422b6f3b16d43d17282f94143eb26cad574977d25781264`
5. ✅ Updated `mx.audioassault.amplocker.yml` with new hash (also fixed a stray indentation issue in the `sources:` block while there)
6. ✅ `just flatpak-install` auto-updated `metainfo.xml` version; release `date` bumped manually to match zip download date (2026-08-16), per the "match the zip's file modification date" convention
7. ✅ Build completed, installed, `flatpak info` confirms Wersja: 1.5.5

No new gotchas this round — same three-file sync procedure as 1.5.4 applied cleanly.

## Version 1.5.4 Upgrade (2026-07-24)

### Successful Update Workflow
The three-file sync requirement was properly executed:
1. ✅ Removed old `AmpLockerLinux.zip` to force re-download
2. ✅ Downloaded v1.5.4 from S3 (219.4 MB, ~22 sec download)
3. ✅ Extracted version from `Amp Locker.vst3/Contents/Resources/moduleinfo.json`
4. ✅ Calculated new SHA256: `7e4955beeac9a0ded3ce1c1102792d266d366cc6ca9a77a5ea148863740b4713`
5. ✅ Updated `mx.audioassault.amplocker.yml` with new hash
6. ✅ Ran `just flatpak-install` which auto-updated `mx.audioassault.amplocker.metainfo.xml`
7. ✅ Build completed, app installed to flatpak

### Key Observations

#### The Three Files Stay in Sync
- `download-and-extract-version` recipe in Justfile updates `metainfo.xml` automatically ✅
- `mx.audioassault.amplocker.yml` SHA256 hash **must** be updated manually ⚠️
  - **Critical gotcha**: If the manifest hash is not updated, flatpak-builder uses the old cached zip while metainfo advertises the new version
  - Symptom: `flatpak info` shows new version but binary is old
  - Solution: Always verify the hash in the manifest matches the zip before building
  
- `AmpLockerLinux.zip` cache cleanup is automatic — `download-and-extract-version` prunes stale `.flatpak-builder/downloads/<old-sha256>/` entries (~200 MB each)

#### Build Performance
- Fresh build + install: ~30 minutes (primarily the rebuild and repo operations)
- Subsequent builds are faster due to cache hits
- The 219.4 MB zip download is the primary bandwidth cost

#### Data Directory Behavior
- `AmpLockerData` symlink strategy is working as designed
- Wrapper script (`amplocker-wrapper.sh`) creates symlink on every launch
- No user-facing issues with preset/IR/NAM data

### Future Upgrade Checklist
When Audio Assault ships a new `AmpLockerLinux.zip`:

1. **Remove the cached zip**: `rm AmpLockerLinux.zip`
2. **Run the build**: `just flatpak`
   - This will download the new zip and auto-update `metainfo.xml`
3. **Extract the version** to confirm upgrade: 
   ```bash
   unzip -p AmpLockerLinux.zip "Amp Locker.vst3/Contents/Resources/moduleinfo.json" | grep -o '"Version": "[^"]*"'
   ```
4. **Calculate the new hash**:
   ```bash
   sha256sum AmpLockerLinux.zip | cut -d' ' -f1
   ```
5. **Update `mx.audioassault.amplocker.yml`** with the new SHA256 in the archive source block (around line 54)
6. **Rebuild and install**: `just flatpak-install`
7. **Commit & push**:
   ```bash
   git add -A && git commit -m "Update to Amp Locker X.Y.Z"
   git push
   ```

### Known Harmless Warnings
- **libcurl version mismatch**: Flatpak prints `/app/libexec/amplocker: /usr/lib/x86_64-linux-gnu/libcurl.so.4: no version information available` on startup. This is cosmetic; the binary was compiled against a different libcurl version and expects version symbols that the system doesn't provide, but the app loads and runs fine. This cannot be fixed without the upstream source code.

### Known Upstream Issues (Not Packaging Bugs)
- **Missing graphics on new amp models after upgrade (found in 1.5.5)**: selecting an amp
  model that didn't exist in the previous version renders with no graphics (looks like it's
  using stale previous-version UI data). Investigated and **ruled out** a packaging/flatpak
  bug:
  - `~/Audio Assault/PluginData/Audio Assault/AmpLockerData` symlink correctly points to
    `/app/share/AmpLocker/AmpLockerData` (not a stale real directory nesting the symlink).
  - Active flatpak deployment dir matched the commit hash reported by `flatpak info` (no
    orphaned/stale deployment).
  - `AmpLockerData` contents (Cabs/, IRs/, NAMs/, Presets/, newgfx.dat) matched 1:1 between
    the upstream zip and the installed flatpak.
  - `newgfx.dat` (149,513,153 bytes — the monolithic graphics blob) sha256 is **identical**
    between the zip and the installed copy: `23328e7c3521329736e30e369f285fbfe8e62744400007add5d8320d6c8db216`.
  - No stale amp-model/graphics-index cache found in `~/Audio Assault/UserData/Amp Locker/`,
    `~/.config/Audio Assault/`, `~/.config/Amp Locker/`, or `~/.config/Amp Locker.settings`
    (CabFileCache.dat is Cabs-specific, unrelated, and was already fresh).
  - **Conclusion**: packaging is byte-for-byte correct; this is most likely an upstream
    application-level bug (would reproduce on a native Linux install too). Try a full quit
    + relaunch first (rules out a stale in-memory asset index carried over from the running
    process across the upgrade); if it persists, report to Audio Assault directly.

### No Known Packaging Issues
- JACK/audio latency tuning remains stable (RTKit D-Bus exposure, no PIPEWIRE_LATENCY forced)
- Filesystem mounts working (xdg-config for JUCE prefs, home/Audio Assault for presets)
- VST3 and LV2 plugins install to correct extension directories
- macOS cruft cleanup still needed (`.DS_Store` files cleaned up during build)

---

**Last updated**: 2026-08-16 (v1.5.5 upgrade)  
**Maintainer contact**: See project README for upstream Audio Assault info
