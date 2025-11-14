#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path('.claude/skills/wasm-oci')
WRAPPER = SKILL_DIR / 'scripts' / 'run-wkg.sh'
LOCAL_WKG = SKILL_DIR / 'scripts' / 'wkg'


def read_payload():
    if len(sys.argv) > 1 and sys.argv[1] != '-':
        raw = sys.argv[1]
    else:
        raw = sys.stdin.read()
    raw = raw.strip()
    if not raw:
        return {}
    return json.loads(raw)


def resolve_runner():
    if WRAPPER.exists() and os.access(WRAPPER, os.X_OK):
        return str(WRAPPER)
    if LOCAL_WKG.exists() and os.access(LOCAL_WKG, os.X_OK):
        return str(LOCAL_WKG)
    return 'wkg'


def run_cmd(cmd, env=None):
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    result.check_returncode()


def action_pull(data, runner):
    reference = data.get('reference')
    if not reference:
        raise SystemExit('`reference` is required for pull action')
    output = data.get('output')
    cmd = [runner, 'oci', 'pull', str(reference)]
    if output:
        cmd.extend(['-o', str(output)])
    cmd.extend([str(flag) for flag in data.get('extra_flags', []) or []])
    run_cmd(cmd)


def action_push(data, runner):
    reference = data.get('reference')
    artifact = data.get('artifact')
    if not reference or not artifact:
        raise SystemExit('`reference` and `artifact` are required for push action')
    cmd = [runner, 'oci', 'push', str(reference), str(artifact)]
    for key, value in (data.get('annotations') or {}).items():
        cmd.extend(['--annotation', f'{key}={value}'])
    cmd.extend([str(flag) for flag in data.get('extra_flags', []) or []])
    env = os.environ.copy()
    if data.get('username'):
        env['WKG_OCI_USERNAME'] = str(data['username'])
    if data.get('password'):
        env['WKG_OCI_PASSWORD'] = str(data['password'])
    run_cmd(cmd, env=env)


def action_raw(data, runner):
    args = data.get('args')
    if not args:
        raise SystemExit('`args` array required for raw action')
    cmd = [runner, *[str(part) for part in args]]
    run_cmd(cmd)


def main():
    data = read_payload()
    action = data.get('action')
    runner = resolve_runner()
    if action == 'pull':
        action_pull(data, runner)
    elif action == 'push':
        action_push(data, runner)
    elif action == 'raw':
        action_raw(data, runner)
    else:
        raise SystemExit('Supported actions: pull, push, raw')


if __name__ == '__main__':
    try:
        main()
    except json.JSONDecodeError as err:
        raise SystemExit(f'Invalid JSON input: {err}')
