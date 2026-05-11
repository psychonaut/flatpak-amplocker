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

flatpak:
    flatpak-builder --force-clean --user .build mx.audioassault.amplocker.yml

flatpak-install:
    flatpak-builder --force-clean --user --install .build mx.audioassault.amplocker.yml

flatpak-run:
    flatpak run mx.audioassault.amplocker
