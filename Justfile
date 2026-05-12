default: flatpak

flatpak: extract-version
    flatpak-builder --force-clean --user .build mx.audioassault.amplocker.yml

flatpak-install: extract-version
    flatpak-builder --force-clean --user --install .build mx.audioassault.amplocker.yml

extract-version:
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(unzip -p AmpLockerLinux.zip "Amp Locker.vst3/Contents/Resources/moduleinfo.json" | grep -o '"Version": "[^"]*"' | head -1 | cut -d'"' -f4)
    sed -i "s|<release version=\"[^\"]*\"|<release version=\"$VERSION\"|" mx.audioassault.amplocker.metainfo.xml
    echo "Updated metainfo.xml to version $VERSION"

flatpak-run:
    flatpak run mx.audioassault.amplocker
