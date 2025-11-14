#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

SKILL_DIR = Path('.claude/skills/awesome-wasm')
WKG_BIN = SKILL_DIR / 'scripts' / 'wkg'
WASM_TOOLS_BIN = SKILL_DIR / 'scripts' / 'wasm-tools'
REGISTRY = SKILL_DIR / 'components.json'


def read_payload():
    if len(sys.argv) > 1 and sys.argv[1] != '-':
        raw = sys.argv[1]
    else:
        raw = sys.stdin.read()
    raw = raw.strip()
    if not raw:
        return {}
    return json.loads(raw)


def resolve_binary(local_path: Path, fallback: str) -> str:
    if local_path.exists() and os.access(local_path, os.X_OK):
        return str(local_path)
    return fallback


def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    result.check_returncode()


def load_registry():
    if REGISTRY.exists():
        with REGISTRY.open() as fh:
            try:
                return json.load(fh)
            except json.JSONDecodeError:
                return {}
    return {}


def save_registry(data):
    REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    with REGISTRY.open('w') as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write('\n')


def action_wkg_pull(data):
    reference = data.get('reference')
    if not reference:
        raise SystemExit('`reference` is required for wkg_pull action')
    output = data.get('output')
    cmd = [resolve_binary(WKG_BIN, 'wkg'), 'oci', 'pull', str(reference)]
    if output:
        cmd.extend(['-o', str(output)])
    run_cmd(cmd)


def action_wasm_tools_wit(data):
    path = data.get('file')
    if not path:
        raise SystemExit('`file` is required for wasm_tools_wit action')
    output = data.get('output')
    if not output:
        raise SystemExit('`output` is required for wasm_tools_wit action')
    cmd = [resolve_binary(WASM_TOOLS_BIN, 'wasm-tools'), 'component', 'wit', str(path), '-o', str(output)]
    run_cmd(cmd)


def action_registry_update(data):
    name = data.get('name')
    if not name:
        raise SystemExit('`name` is required for registry_update action')
    registry = load_registry()
    entry = registry.get(name, {})
    for key in ['reference', 'file', 'notes', 'category']:
        if data.get(key) is not None:
            entry[key] = data[key]
    entry['last_updated'] = datetime.utcnow().isoformat() + 'Z'
    registry[name] = entry
    save_registry(registry)
    print(json.dumps({name: entry}, indent=2))


def action_registry_list():
    print(json.dumps(load_registry(), indent=2))


def main():
    data = read_payload()
    action = data.get('action')
    if action == 'wkg_pull':
        action_wkg_pull(data)
    elif action == 'wasm_tools_wit':
        action_wasm_tools_wit(data)
    elif action == 'registry_update':
        action_registry_update(data)
    elif action == 'registry_list':
        action_registry_list()
    else:
        raise SystemExit('Supported actions: wkg_pull, wasm_tools_wit, registry_update, registry_list')


if __name__ == '__main__':
    try:
        main()
    except json.JSONDecodeError as err:
        raise SystemExit(f'Invalid JSON input: {err}')
