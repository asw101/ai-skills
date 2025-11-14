#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

DEFAULTS = {
    'rust': [['cargo', 'component', 'build', '--release', '--target', 'wasm32-wasip2']],
    'python': [['componentize-py', 'componentize']],
    'javascript': [['npm', 'run', 'build:component']],
    'go': [['tinygo', 'build', '-target', 'wasip2', '--wit-package', './wit', '-o', '../component.wasm', '.']],
}


def read_payload():
    if len(sys.argv) > 1 and sys.argv[1] != '-':
        raw = sys.argv[1]
    else:
        raw = sys.stdin.read()
    raw = raw.strip()
    if not raw:
        return {}
    return json.loads(raw)


def run_command(command, cwd, env):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, env=env)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    result.check_returncode()


def main():
    data = read_payload()
    language = (data.get('language') or '').lower()
    directory = data.get('directory')
    if not directory:
        raise SystemExit('`directory` is required')
    workdir = Path(directory)
    if not workdir.exists():
        raise SystemExit(f'Build directory not found: {workdir}')

    env = os.environ.copy()
    env.update({str(k): str(v) for k, v in (data.get('env') or {}).items()})

    commands = data.get('commands')
    if commands:
        normalized = []
        for entry in commands:
            if isinstance(entry, str):
                normalized.append(shlex.split(entry))
            elif isinstance(entry, list):
                normalized.append([str(part) for part in entry])
            else:
                raise SystemExit('Commands must be strings or arrays')
        commands_to_run = normalized
    else:
        commands_to_run = DEFAULTS.get(language)
        if not commands_to_run:
            raise SystemExit('Provide `language` (rust/python/javascript/go) or custom `commands`.')

    for command in commands_to_run:
        run_command(command, cwd=str(workdir), env=env)


if __name__ == '__main__':
    try:
        main()
    except json.JSONDecodeError as err:
        raise SystemExit(f'Invalid JSON input: {err}')
