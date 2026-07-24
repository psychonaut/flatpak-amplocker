# Session Notes & Observations

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

### No Known Issues
- JACK/audio latency tuning remains stable (RTKit D-Bus exposure, no PIPEWIRE_LATENCY forced)
- Filesystem mounts working (xdg-config for JUCE prefs, home/Audio Assault for presets)
- VST3 and LV2 plugins install to correct extension directories
- macOS cruft cleanup still needed (`.DS_Store` files cleaned up during build)

---

**Last updated**: 2026-07-24  
**Maintainer contact**: See project README for upstream Audio Assault info
