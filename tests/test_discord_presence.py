from pathlib import Path
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
import unittest

BINARY = Path(__file__).resolve().parent.parent / 'tools/discord/discord-presence'


def read_exact(connection, size):
    result = b''
    while len(result) < size:
        chunk = connection.recv(size - len(result))
        if not chunk: raise EOFError('Helper disconnected')
        result += chunk
    return result


def receive(connection):
    opcode, size = struct.unpack('<II', read_exact(connection, 8))
    if size > 65536: raise ValueError('Unexpected helper packet')
    return opcode, read_exact(connection, size)


def send(connection, opcode, data, fragmented=False):
    payload = struct.pack('<II', opcode, len(data)) + data
    if fragmented:
        connection.sendall(payload[:3]); time.sleep(.02); connection.sendall(payload[3:])
    else: connection.sendall(payload)


class DiscordArtifactChecks(unittest.TestCase):
    def test_helper_has_both_architectures(self):
        data = BINARY.read_bytes()
        self.assertEqual(struct.unpack_from('>II', data), (0xCAFEBABE, 2))
        architectures = set()
        for index in range(2):
            cpu, _, offset, size, _ = struct.unpack_from('>IIIII', data, 8 + index * 20)
            self.assertGreater(size, 0); self.assertLessEqual(offset + size, len(data))
            architectures.add(cpu)
        self.assertEqual(architectures, {0x01000007, 0x0100000C})


@unittest.skipUnless(sys.platform == 'darwin', 'native macOS helper')
class DiscordProtocolChecks(unittest.TestCase):
    def exercise(self, mode):
        with tempfile.TemporaryDirectory(prefix='br-discord-') as scratch:
            # Point only this child at our fake socket; never contact the real Discord client.
            environment = dict(os.environ, TMPDIR=scratch)
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(Path(scratch) / 'discord-ipc-0')); server.listen(); server.settimeout(5)
                parent = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(1.5)'])
                helper = subprocess.Popen([str(BINARY), str(parent.pid)], env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    connection, _ = server.accept()
                    with connection:
                        connection.settimeout(5)
                        opcode, payload = receive(connection)
                        self.assertEqual(opcode, 0)
                        self.assertEqual(json.loads(payload), {'v': 1, 'client_id': '1225535693791432814'})
                        if mode == 'malformed':
                            connection.sendall(struct.pack('<II', 1, 65537))
                        else:
                            send(connection, 1, b'{"cmd":"DISPATCH","evt":"READY"}', fragmented=True)
                            opcode, payload = receive(connection); activity = json.loads(payload)
                            self.assertEqual((opcode, activity['cmd'], activity['args']['pid']), (1, 'SET_ACTIVITY', parent.pid))
                            self.assertGreater(activity['args']['activity']['timestamps']['start'], 0)
                            send(connection, 1, json.dumps({'cmd': 'SET_ACTIVITY', 'nonce': activity['nonce']}).encode())
                            send(connection, 3, b'ping')
                            self.assertEqual(receive(connection), (4, b'ping'))
                            parent.wait(timeout=5)
                            opcode, payload = receive(connection); cleared = json.loads(payload)
                            self.assertEqual((opcode, cleared['cmd'], cleared['args']), (1, 'SET_ACTIVITY', {'pid': parent.pid}))
                    parent.wait(timeout=5)
                    output, errors = helper.communicate(timeout=5)
                    self.assertEqual(helper.returncode, 0)
                    self.assertEqual((output, errors), (b'', b''))
                finally:
                    for process in [helper, parent]:
                        if process.poll() is None: process.terminate()
                        process.wait(timeout=5)

    def test_fragmented_ready_activity_ping_and_parent_exit_cleanup(self): self.exercise('normal')
    def test_oversized_frame_cannot_keep_helper_alive_after_game_exit(self): self.exercise('malformed')
