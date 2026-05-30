default: flatpak

flatpak: download-and-extract-version
    flatpak-builder --force-clean --user --repo=repo .build mx.audioassault.amplocker.yml

flatpak-install: download-and-extract-version
    flatpak-builder --force-clean --user --repo=repo --install .build mx.audioassault.amplocker.yml

download-and-extract-version:
    #!/usr/bin/env bash
    set -euo pipefail
    
    ZIP_URL="https://audioassaultdownloads.s3.amazonaws.com/AmpLocker/AmpLocker109/AmpLockerLinux.zip"
    ZIP_FILE="AmpLockerLinux.zip"
    
    # Download zip if not present or force refresh
    if [[ ! -f "$ZIP_FILE" ]]; then
        echo "Downloading $ZIP_FILE..."
        curl -L -o "$ZIP_FILE" "$ZIP_URL"
    else
        echo "Using existing $ZIP_FILE (delete to force re-download)"
    fi
    
    # Extract version from the zip
    VERSION=$(unzip -p "$ZIP_FILE" "Amp Locker.vst3/Contents/Resources/moduleinfo.json" | grep -o '"Version": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    # Update metainfo.xml
    sed -i "s|<release version=\"[^\"]*\"|<release version=\"$VERSION\"|" mx.audioassault.amplocker.metainfo.xml
    echo "Updated metainfo.xml to version $VERSION"

flatpak-bundle: flatpak
    #!/usr/bin/env bash
    set -euo pipefail
    VERSION=$(grep -o '<release version="[^"]*"' mx.audioassault.amplocker.metainfo.xml | head -1 | cut -d'"' -f2)
    flatpak build-bundle repo "mx.audioassault.amplocker-${VERSION}.flatpak" mx.audioassault.amplocker
    echo "Created mx.audioassault.amplocker-${VERSION}.flatpak"

flatpak-run:
    flatpak run mx.audioassault.amplocker
