#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path('.claude/skills/just')
LOCAL_BIN = SKILL_DIR / 'scripts' / 'just'
DEFAULT_BIN = 'just'


def read_payload() -> dict:
    if len(sys.argv) > 1 and sys.argv[1] != '-':
        raw = sys.argv[1]
    else:
        raw = sys.stdin.read()
    raw = raw.strip()
    if not raw:
        return {}
    return json.loads(raw)


def resolve_binary() -> str:
    if LOCAL_BIN.exists() and os.access(LOCAL_BIN, os.X_OK):
        return str(LOCAL_BIN)
    return DEFAULT_BIN


def run_command(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    result.check_returncode()


def main():
    data = read_payload()
    action = data.get('action', 'list')
    recipe = data.get('recipe')
    args = data.get('args', []) or []

    binary = resolve_binary()

    if action == 'list':
        cmd = [binary, '--list']
    elif action == 'summary':
        cmd = [binary, '--summary']
    elif action == 'show':
        if not recipe:
            raise SystemExit('`recipe` is required for the show action')
        cmd = [binary, '--show', recipe]
    elif action == 'run':
        if not recipe:
            raise SystemExit('`recipe` is required for the run action')
        if not isinstance(args, list):
            raise SystemExit('`args` must be a list of strings')
        cmd = [binary, recipe, *[str(a) for a in args]]
    else:
        raise SystemExit(f'Unsupported action: {action}')

    run_command(cmd)


if __name__ == '__main__':
    try:
        main()
    except json.JSONDecodeError as err:
        raise SystemExit(f'Invalid JSON input: {err}')
