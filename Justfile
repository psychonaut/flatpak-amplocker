default: build

build: clean unzip rsync

clean:
    rm -rf amplocker

unzip:
    unzip AmpLockerLinux.zip -d amplocker
    find amplocker -name '__MACOSX' -type d -exec rm -rf {} \+
    find amplocker -name .DS_Store -type f -delete
    mv amplocker/Amp\ Locker\ Standalone amplocker/mx.audioassault.amplocker

rsync:
    rsync -av amplocker/AmpLockerData/ $HOME/Audio\ Assault/PluginData/AudioAssault/AmpLockerData

flatpak: extract-version
    flatpak-builder --force-clean --user .build mx.audioassault.amplocker.yml

flatpak-install: extract-version
    flatpak-builder --force-clean --user --install .build mx.audioassault.amplocker.yml

extract-version:
    VERSION=$$(unzip -p AmpLockerLinux.zip "Amp Locker.vst3/Contents/Resources/moduleinfo.json" | grep -o '"Version": "[^"]*"' | head -1 | cut -d'"' -f4) && \
    sed -i "s/version=\"[^\"]*\"/version=\"$$VERSION\"/" mx.audioassault.amplocker.metainfo.xml && \
    echo "Updated metainfo.xml to version $$VERSION"

flatpak-run:
    flatpak run mx.audioassault.amplocker
