#!/bin/bash
# Fedora 44 x86_64 prototype. Build output and downloaded headers stay in /tmp.
set -euo pipefail
kotofox_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
kotofox_uda_source=https://github.com/yceachan/SDK.git
kotofox_uda_commit=622436a3d665fdd9cfe769fc85b049eadcd38e65
kotofox_work=$(mktemp -d /tmp/kotofox-build.XXXXXX)
kotofox_stage="$kotofox_work/kotofox-0.1.0"
mkdir -p "$kotofox_stage" "$kotofox_source/.packages" "$kotofox_work/rpms" "$kotofox_work/sdk" "$kotofox_work/native"
printf 'Build directory: %s\n' "$kotofox_work"
/usr/bin/python3 -s -c 'from PyQt6.QtCore import qVersion; assert qVersion().startswith("6.11."), qVersion(); import kotonoha, qasync, aiohttp, dbus_fast'
cp -a "$kotofox_source/src" "$kotofox_source/assets" "$kotofox_source/kotofox" "$kotofox_source/try-local.sh" "$kotofox_source/kotofox.desktop.in" "$kotofox_source/kotofox.service.in" "$kotofox_source/LICENSE" "$kotofox_stage/"
mkdir -p "$kotofox_stage/vendor" "$kotofox_stage/bin" "$kotofox_stage/lib" "$kotofox_stage/licenses"
cp /usr/bin/musicfox "$kotofox_stage/bin/musicfox"
/usr/bin/python3 -s - "$kotofox_stage" <<'PY'
import importlib.metadata, pathlib, shutil, sys
import kotonoha
if importlib.metadata.version('kotonoha') != '0.2.3':
    raise RuntimeError('This prototype requires the installed Kotonoha 0.2.3')
stage = pathlib.Path(sys.argv[1])
shutil.copytree(pathlib.Path(kotonoha.__file__).parent, stage/'vendor/kotonoha', ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
PY
git clone --quiet "$kotofox_uda_source" "$kotofox_work/uda"
git -C "$kotofox_work/uda" checkout --quiet "$kotofox_uda_commit"
cargo build --release --locked --manifest-path "$kotofox_work/uda/Cargo.toml" -p uda-ffi > "$kotofox_work/uda-build.log" 2>&1
cp "$kotofox_work/uda/target/release/libuda_ffi.so" "$kotofox_stage/lib/"
cp "$kotofox_work/uda/LICENSE-MIT" "$kotofox_stage/licenses/UDA-MIT"
cp "$kotofox_work/uda/LICENSE-APACHE" "$kotofox_stage/licenses/UDA-APACHE"
git clone --quiet https://github.com/locez/kotonoha.git "$kotofox_work/kotonoha"
git -C "$kotofox_work/kotonoha" checkout --quiet 175cfcc04ffb67fbbba26c76437275083090233a
cp "$kotofox_work/kotonoha/LICENSE" "$kotofox_stage/licenses/Kotonoha"
cp -a "$kotofox_work/kotonoha/LICENSES" "$kotofox_stage/licenses/Kotonoha-LICENSES"
curl -fsSL https://raw.githubusercontent.com/go-musicfox/go-musicfox/v5.1.0/LICENSE -o "$kotofox_stage/licenses/Musicfox"
# Extract development RPMs without installing packages or changing system Qt.
dnf download --arch=x86_64 --destdir="$kotofox_work/rpms" \
    qt6-qtbase-devel-6.11.2-2.fc44 qt6-qtbase-private-devel-6.11.2-2.fc44 \
    layer-shell-qt-devel-6.7.5-1.fc44 wayland-devel-1.26.0-1.fc44 \
    > "$kotofox_work/headers-download.log" 2>&1
for kotofox_rpm in "$kotofox_work"/rpms/*.rpm; do
    (cd "$kotofox_work/sdk" && rpm2cpio "$kotofox_rpm" | cpio -idm --quiet)
done
for kotofox_protocol in blur ext-background-effect-v1; do
    "$kotofox_work/sdk/usr/bin/wayland-scanner" client-header \
        "$kotofox_work/kotonoha/src/kotonoha/protocols/$kotofox_protocol.xml" \
        "$kotofox_work/native/$kotofox_protocol-client-protocol.h"
    "$kotofox_work/sdk/usr/bin/wayland-scanner" private-code \
        "$kotofox_work/kotonoha/src/kotonoha/protocols/$kotofox_protocol.xml" \
        "$kotofox_work/native/$kotofox_protocol-protocol.c"
    gcc -fPIC -I"$kotofox_work/sdk/usr/include" \
        -c "$kotofox_work/native/$kotofox_protocol-protocol.c" \
        -o "$kotofox_work/native/$kotofox_protocol.o"
done
g++ -O2 -std=c++17 -shared -fPIC -DKOTONOHA_HAVE_BLUR \
    -I"$kotofox_work/native" -I"$kotofox_work/sdk/usr/include" \
    -I"$kotofox_work/sdk/usr/include/qt6" \
    -I"$kotofox_work/sdk/usr/include/qt6/QtCore" \
    -I"$kotofox_work/sdk/usr/include/qt6/QtGui" \
    -I"$kotofox_work/sdk/usr/include/qt6/QtGui/6.11.2/QtGui" \
    -I"$kotofox_work/sdk/usr/include/qt6/QtCore/6.11.2" \
    -I"$kotofox_work/sdk/usr/include/qt6/QtCore/6.11.2/QtCore" \
    "$kotofox_work/kotonoha/src/kotonoha/layer_shell_bridge.cpp" \
    "$kotofox_work/native/blur.o" "$kotofox_work/native/ext-background-effect-v1.o" \
    /usr/lib64/libQt6Core.so.6 /usr/lib64/libQt6Gui.so.6 \
    /usr/lib64/libLayerShellQtInterface.so.6 /usr/lib64/libwayland-client.so.0 \
    -o "$kotofox_stage/vendor/kotonoha/libkoto-layer.so" \
    > "$kotofox_work/native-build.log" 2>&1
/usr/bin/python3 -s - "$kotofox_stage" "$kotofox_uda_source" "$kotofox_uda_commit" <<'PY'
import hashlib, json, pathlib, sys
stage = pathlib.Path(sys.argv[1])
manifest = {'version': '0.1.0', 'target': 'Fedora 44 KDE Wayland x86_64 / system Qt 6.11',
    'uda_source': sys.argv[2], 'uda_commit': sys.argv[3],
    'kotonoha_commit': '175cfcc04ffb67fbbba26c76437275083090233a',
    'kotonoha_version': '0.2.3', 'musicfox_version': '5.1.0',
    'musicfox_source': 'https://github.com/go-musicfox/go-musicfox/tree/v5.1.0',
    'sha256': {}}
for name in ('bin/musicfox','lib/libuda_ffi.so','vendor/kotonoha/libkoto-layer.so',
             'src/lyrics.py','src/main.py','src/player.py','src/tray.py','src/focus-player.js','src/kwin_rules.py','assets/kotofox.svg'):
    manifest['sha256'][name] = hashlib.sha256((stage/name).read_bytes()).hexdigest()
(stage/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
PY
tar --exclude=__pycache__ --exclude='*.pyc' -czf "$kotofox_source/.packages/kotofox-0.1.0-fedora44-x86_64.tar.gz" -C "$kotofox_work" kotofox-0.1.0
printf 'Package: %s\n' "$kotofox_source/.packages/kotofox-0.1.0-fedora44-x86_64.tar.gz"
