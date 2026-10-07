import asyncio
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from dbus_fast.aio import MessageBus
from dbus_fast import Message, MessageType, Variant
sys.path.insert(0, '/home/pi/.local/lib/kotofox/src')
from main import request

ROOT = Path('/home/pi/.local/lib/kotofox')
OUT = Path('/tmp/kotofox-pr')

def pane_pid():
    return int(subprocess.check_output(['tmux', 'list-panes', '-t', '=musicfox:', '-F', '#{pane_pid}'], text=True).strip())

async def main():
    before = json.loads((OUT / 'before-install.json').read_text())
    bus = await MessageBus().connect()
    async def call(**kwargs):
        response = await asyncio.wait_for(bus.call(Message(**kwargs)), 5)
        if response.message_type == MessageType.ERROR:
            raise RuntimeError(str(response.body))
        return response
    async def status_until(key, value):
        for _ in range(50):
            status = request('status')
            if status[key] == value:
                return status
            await asyncio.sleep(.1)
        raise AssertionError(f'{key} did not become {value}: {status}')
    names = await call(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus', interface='org.freedesktop.DBus', member='ListNames')
    services = [name for name in names.body[0] if name.startswith('org.kde.StatusNotifierItem-Kotofox-')]
    assert len(services) == 1, services
    service = services[0]
    assert not any(name.startswith('org.kde.StatusNotifierItem-kotonoha-') for name in names.body[0]), names.body[0]
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    manager_pid = int(subprocess.check_output(['systemctl', '--user', 'show', 'kotofox.service', '-p', 'MainPID', '--value'], text=True))
    maps = Path(f'/proc/{manager_pid}/maps').read_text()
    assert str(ROOT / 'lib/libuda_ffi.so') in maps, maps
    library_hash = hashlib.sha256((ROOT / 'lib/libuda_ffi.so').read_bytes()).hexdigest()
    assert library_hash == manifest['sha256']['lib/libuda_ffi.so'], manifest
    initial = request('status')
    assert initial['layer_shell_active'] and initial['qt_platform'] == 'wayland', initial
    assert pane_pid() == before['pane_pid'], before
    menu_property = await call(destination=service, path='/StatusNotifierItem', interface='org.freedesktop.DBus.Properties', member='Get', signature='ss', body=['org.kde.StatusNotifierItem', 'Menu'])
    assert menu_property.body[0].signature == 'o', menu_property.body
    menu_path = menu_property.body[0].value
    layout = await call(destination=service, path=menu_path, interface='com.canonical.dbusmenu', member='GetLayout', signature='iias', body=[0, -1, []])
    assert layout.signature == 'u(ia{sv}av)', layout.signature
    rows = {child.value[1]['label'].value: child.value[0] for child in layout.body[1][2] if 'label' in child.value[1]}
    async def click(label):
        await call(destination=service, path='/MenuBar', interface='com.canonical.dbusmenu', member='Event', signature='isvu', body=[rows[label], 'clicked', Variant('s', ''), 0])
    for label, visible in [('隐藏桌面歌词', False), ('显示桌面歌词', True)]:
        await click(label)
        await status_until('lyrics_visible', visible)
    await click('关闭播放器窗口，保留播放')
    for _ in range(50):
        terminal_pid = request('status')['terminal_pid']
        if terminal_pid is None or not Path(f'/proc/{terminal_pid}').exists():
            break
        await asyncio.sleep(.1)
    else:
        raise AssertionError('Konsole did not close')
    assert pane_pid() == before['pane_pid']
    await click('打开播放器')
    for _ in range(50):
        final = request('status')
        if final['terminal_pid'] and Path(f"/proc/{final['terminal_pid']}").exists():
            break
        await asyncio.sleep(.1)
    else:
        raise AssertionError('Konsole did not reopen')
    assert pane_pid() == before['pane_pid']
    await call(destination=service, path='/MenuBar', interface='com.canonical.dbusmenu', member='GetLayout', signature='iias', body=[0, -1, []])
    owner = await call(destination='org.freedesktop.DBus', path='/org/freedesktop/DBus', interface='org.freedesktop.DBus', member='NameHasOwner', signature='s', body=[service])
    assert owner.body == [True], owner.body
    record = {'sdk_commit': manifest['uda_commit'], 'library_sha256': library_hash, 'library_mapped_in_manager': True, 'manager_pid': manager_pid, 'signature': layout.signature, 'menu_property_signature': menu_property.body[0].signature, 'menu_path': menu_path, 'service': service, 'menu_labels': list(rows), 'show_hide_callbacks': True, 'close_reopen_callbacks': True, 'name_has_owner_after_callbacks': True, 'kotofox_tray_count': len(services), 'bare_kotonoha_tray_absent': True, 'player_pid_before': before['pane_pid'], 'player_pid_after': pane_pid(), 'state': final}
    (OUT / 'e2e.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(record, ensure_ascii=False, indent=2))
    bus.disconnect()

asyncio.run(main())
