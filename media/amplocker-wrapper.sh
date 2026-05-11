#!/bin/sh
# Amp Locker launcher.
#
# Tops up AmpLockerData in the user's home with any files that don't already
# exist there. The proprietary binary reads its presets/cabs/IRs/NAMs from
# $HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData/ (note: the
# "Audio Assault" segment appears twice, with a space). The flatpak ships a
# read-only copy at /app/share/AmpLocker/AmpLockerData/ for first-run sync.
#
# Strategy: `cp -Rn` — copy recursively, never clobber. New presets/IRs that
# upstream adds in future releases will appear on next launch, and anything
# the user has edited or added themselves is left untouched. Files the user
# *deletes* will reappear on next launch; that's the trade-off of the
# "always top-up" strategy (vs. a one-shot sentinel file).

set -eu

DATA_SRC="/app/share/AmpLocker/AmpLockerData"
DATA_DST="$HOME/Audio Assault/PluginData/Audio Assault/AmpLockerData"

if [ -d "$DATA_SRC" ]; then
    mkdir -p "$DATA_DST"
    # `cp -Rn` is POSIX-ish (BSD/GNU both honour -n = no-clobber). The
    # trailing /. on the source copies *contents* rather than nesting the
    # directory inside the destination.
    cp -Rn "$DATA_SRC/." "$DATA_DST/" 2>/dev/null || true
fi

exec /app/libexec/amplocker "$@"
