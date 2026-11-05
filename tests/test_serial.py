#!/usr/bin/env python3
"""Exercise the built IOC through a PTY; no physical device or CA client needed."""
import os
from pathlib import Path
import pty
import select
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


def check_location(location, channels):
    master, slave = pty.openpty()
    commands = []
    values = {(ch, par): value for ch in range(channels) for par, value in
              [('VSET', '12.34'), ('ISET', '0.015'), ('RUP', '7'), ('RDW', '9'),
               ('VMON', '12.34'), ('IMON', '0.0005'), ('STAT', '1')]}
    stop = threading.Event()
    reject = threading.Event()

    def serve():
        pending = b''
        while not stop.is_set():
            if not select.select([master], [], [], 0.1)[0]:
                continue
            pending += os.read(master, 4096)
            while b'\r\n' in pending:
                raw, pending = pending.split(b'\r\n', 1)
                command = raw.decode()
                commands.append(command)
                fields = dict(part.split(':', 1) for part in command[1:].split(','))
                key = (int(fields['CH']), fields['PAR'])
                response = '#BD:00,CMD:OK'
                if fields['CMD'] == 'MON':
                    response += ',VAL:' + values[key]
                elif reject.is_set():
                    response = '#BD:00,CMD:ERR'
                elif 'VAL' in fields:
                    values[key] = fields['VAL']
                os.write(master, (response + '\r\n').encode())

    thread = threading.Thread(target=serve, daemon=True)
    thread.start()
    env = dict(os.environ, PV_LOCATION=location, CAEN_DEVICE=os.ttyname(slave),
               MUSIC_PREFIX='TEST:N1410:', EPICS_CA_AUTO_ADDR_LIST='NO',
               EPICS_CA_ADDR_LIST='127.0.0.1', EPICS_CAS_INTF_ADDR_LIST='127.0.0.1',
               EPICS_CAS_SERVER_PORT='15064')
    log = ROOT / 'tests' / f'{location}.log'
    proc = None
    try:
        with log.open('w') as output:
            proc = subprocess.Popen([str(ROOT / 'run.sh')], stdin=subprocess.PIPE,
                                    stdout=output, stderr=subprocess.STDOUT, text=True, env=env)
            time.sleep(3)
            assert proc.poll() is None, log.read_text()
            assert len(commands) >= channels * 4, log.read_text()
            assert all('CMD:MON' in cmd for cmd in commands), commands
            assert {int(c.split('CH:')[1].split(',')[0]) for c in commands} == set(range(channels))
            for suffix, value in [('V_SET', '123.46'), ('I_SET', '0.015'),
                                  ('RAMP_UP_SET', '25'), ('RAMP_DOWN_SET', '30'),
                                  ('ENABLE', '1'), ('ENABLE', '0'),
                                  ('V_SET', '1500'), ('I_SET', '300'),
                                  ('RAMP_UP_SET', '200')]:
                subsystem = 'POSITIVE' if suffix == 'I_SET' else 'PHV'
                proc.stdin.write(f'dbpf TEST:N1410:FC1:{subsystem}:{suffix} {value}\n')
                proc.stdin.flush()
                time.sleep(0.2)
            for fragment in ['PAR:VSET,VAL:123.46', 'PAR:ISET,VAL:0.015',
                             'PAR:RUP,VAL:25', 'PAR:RDW,VAL:30', 'PAR:ON', 'PAR:OFF',
                             'PAR:VSET,VAL:500.00', 'PAR:ISET,VAL:200.000', 'PAR:RUP,VAL:100']:
                assert any('CMD:SET' in c and fragment in c for c in commands), (fragment, commands)
            reject.set()
            proc.stdin.write('dbpf TEST:N1410:FC1:PHV:V_SET 100\n')
            proc.stdin.flush()
            time.sleep(0.3)
            proc.stdin.write('dbgf TEST:N1410:FC1:POSITIVE:V_SET.SEVR\nexit\n')
            proc.stdin.flush()
            proc.wait(timeout=10)
        text = log.read_text()
        assert 'INVALID' in text, text
        assert 'Protocol not found' not in text and 'No such file' not in text, text
        print(f'{location}: startup read-only, mapping, precision, limits, ON/OFF and error alarm passed')
    finally:
        if proc is not None and proc.poll() is None:
            proc.kill()
            proc.wait()
        stop.set()
        thread.join(timeout=2)
        os.close(master)
        os.close(slave)


if __name__ == '__main__':
    check_location('FHF1', 3)
    check_location('FMF1', 2)
