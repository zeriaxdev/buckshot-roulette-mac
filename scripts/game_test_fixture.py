"""Shared, disposable game-data extraction and SDK isolation for local tests."""
import re
import struct


def extract(pck, dest, full):
    with pck.open('rb') as f:
        magic, version = struct.unpack('<II', f.read(8))
        if magic != 0x43504447 or version != 2:
            raise ValueError('Expected an unencrypted Godot 4 PCK')
        f.read(12)
        flags, base = struct.unpack('<IQ', f.read(12))
        if flags & 1:
            raise ValueError('Encrypted PCK directories are not supported')
        f.read(64)
        count, = struct.unpack('<I', f.read(4))
        entries = []
        for _ in range(count):
            length, = struct.unpack('<I', f.read(4))
            if length > 65536:
                raise ValueError('Invalid PCK path length')
            name = f.read(length).rstrip(b'\0').decode().removeprefix('res://')
            offset, size = struct.unpack('<QQ', f.read(16))
            f.read(20)
            path = dest / name
            if not path.resolve().is_relative_to(dest.resolve()):
                raise ValueError('PCK path escapes test folder')
            if full or name in ('scripts/BlinkerBranch.gd', 'scripts/BpmLight.gd', 'scripts/PartitionBranch.gd'):
                entries.append((path, base + offset, size))
        for path, offset, size in entries:
            f.seek(offset)
            data = f.read(size)
            if len(data) != size:
                raise ValueError('Truncated PCK entry')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)


def isolate_runtime(project):
    """Disable SDK initialization only in the disposable extracted test project."""
    steam = project / 'scripts/Steam.gd'
    text, count = re.subn(
        r'(?ms)^func (_ready|_process)\([^\n]*\n.*?(?=^func |\Z)',
        lambda m: f'func {m[1]}({"_delta" if m[1] == "_process" else ""}):\n\tpass\n\n',
        steam.read_text(),
    )
    if count != 2:
        raise ValueError('Unexpected Steam script layout in test fixture')
    globals_file = project / 'scripts/GlobalVariables.gd'
    globals_text = globals_file.read_text()
    if globals_text.count('var using_steam = true') != 1:
        raise ValueError('Unexpected Steam flag in test fixture')
    steam.write_text(text)
    globals_file.write_text(globals_text.replace('var using_steam = true', 'var using_steam = false'))
