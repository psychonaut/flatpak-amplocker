#!/bin/sh
# Amp Locker launcher.
#
# AmpLockerData is immutable (shipped with the flatpak, never modified by
# the user). The proprietary binary reads it from the hardcoded path:
#   $HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData/
# (note: the "Audio Assault" segment appears twice, with a space).
#
# Strategy: symlink it straight to the flatpak bundle. No I/O on every
# launch, and upstream updates take effect instantly.

set -eu

DATA_SRC="/app/share/AmpLocker/AmpLockerData"
DATA_DST_DIR="$HOME/Audio Assault/PluginData/Audio Assault"
DATA_DST="$DATA_DST_DIR/AmpLockerData"

if [ -d "$DATA_SRC" ]; then
    mkdir -p "$DATA_DST_DIR"
    if [ -L "$DATA_DST" ]; then
        # Already a symlink — replace only if it points to the wrong place.
        if [ "$(readlink "$DATA_DST")" != "$DATA_SRC" ]; then
            rm -f "$DATA_DST"
            ln -s "$DATA_SRC" "$DATA_DST"
        fi
    elif [ -d "$DATA_DST" ]; then
        # Real directory (left over from a cp-based install) — back it up
        # before replacing with a symlink, just in case.
        mv "$DATA_DST" "$DATA_DST.bak"
        ln -s "$DATA_SRC" "$DATA_DST"
    else
        ln -s "$DATA_SRC" "$DATA_DST"
    fi
fi

exec /app/libexec/amplocker "$@"
