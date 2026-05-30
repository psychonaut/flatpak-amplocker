#!/bin/sh
# Amp Locker launcher.
#
# Syncs AmpLockerData from the flatpak bundle into the user's home. The
# proprietary binary reads its presets/cabs/IRs/NAMs/gfx from
# $HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData/ (note: the
# "Audio Assault" segment appears twice, with a space). The flatpak ships a
# read-only copy at /app/share/AmpLocker/AmpLockerData/.
#
# Strategy: `cp -Ruf` — recursive, update-only (skip if destination is
# newer or same age). New files and files with a newer source timestamp
# are copied; unchanged files are skipped. This guarantees upstream
# updates land automatically while avoiding redundant I/O on every launch.

set -eu

DATA_SRC="/app/share/AmpLocker/AmpLockerData"
DATA_DST="$HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData"

if [ -d "$DATA_SRC" ]; then
    mkdir -p "$DATA_DST"
    # `cp -Ruf` — recursive, force-overwrite only when source is newer
    # (-u = update). The trailing /. on the source copies *contents*
    # rather than nesting the directory inside the destination.
    cp -Ruf "$DATA_SRC/." "$DATA_DST/" 2>/dev/null || true
fi

exec /app/libexec/amplocker "$@"
