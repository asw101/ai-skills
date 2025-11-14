#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path('.claude/skills/wasmtime')
LOCAL_BIN = SKILL_DIR / 'scripts' / 'wasmtime'
DEFAULT_BIN = 'wasmtime'


def read_payload():
    if len(sys.argv) > 1 and sys.argv[1] != '-':
        raw = sys.argv[1]
    else:
        raw = sys.stdin.read()
    raw = raw.strip()
    if not raw:
        return {}
    return json.loads(raw)


def resolve_binary():
    if LOCAL_BIN.exists() and os.access(LOCAL_BIN, os.X_OK):
        return str(LOCAL_BIN)
    return DEFAULT_BIN


def run_cmd(cmd, env=None):
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    result.check_returncode()


def main():
    data = read_payload()
    action = data.get('action', 'run')
    target = data.get('file')
    binary = resolve_binary()

    if action == 'run':
        if not target:
            raise SystemExit('`file` is required for run action')
        cmd = [binary, 'run']
        for directory in data.get('dirs', []) or []:
            cmd.extend(['--dir', str(directory)])
        for key, value in (data.get('env') or {}).items():
            cmd.extend(['--env', f'{key}={value}'])
        if data.get('invoke'):
            cmd.extend(['--invoke', str(data['invoke'])])
        if data.get('wasi_preview'):
            cmd.extend(['--wasi', str(data['wasi_preview'])])
        for extra in data.get('extra_args', []) or []:
            cmd.append(str(extra))
        cmd.append(str(target))
        run_cmd(cmd)
    elif action == 'wit':
        if not target:
            raise SystemExit('`file` is required for wit action')
        output = data.get('output')
        if not output:
            raise SystemExit('`output` is required for wit action')
        cmd = [binary, 'component', 'wit', str(target), '-o', str(output)]
        run_cmd(cmd)
    elif action == 'compile':
        if not target:
            raise SystemExit('`file` is required for compile action')
        output = data.get('output')
        if not output:
            raise SystemExit('`output` is required for compile action')
        cmd = [binary, 'compile', str(target), '-o', str(output)]
        run_cmd(cmd)
    else:
        raise SystemExit(f'Unsupported action: {action}')


if __name__ == '__main__':
    try:
        main()
    except json.JSONDecodeError as err:
        raise SystemExit(f'Invalid JSON input: {err}')
