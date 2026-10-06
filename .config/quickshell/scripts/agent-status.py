#!/usr/bin/env python3
"""List local agent sessions by executable identity, without exposing arguments."""
import json
import os
import re
from pathlib import Path

AGENTS = {
    'codex': ('Antigravity', 'antigravity.png'), 'openai-codex': ('Codex', 'codex.svg'),
    'claude': ('Claude Code', 'claude.svg'), 'claude-code': ('Claude Code', 'claude.svg'),
    'agy': ('Antigravity', 'antigravity.png'), 'gemini': ('Gemini', 'gemini.svg'),
    'opencode': ('OpenCode', ''), 'aider': ('Aider', ''),
    'devin': ('Devin', ''), 'devin-cli': ('Devin', ''),
    'copilot': ('Copilot', 'copilot.svg'), 'cursor-agent': ('Cursor', ''),
}
INTERPRETERS = {'node', 'nodejs', 'bun', 'deno', 'python', 'python3'}
PACKAGES = (
    ('@anthropic-ai/claude-code/', 'claude'), ('@openai/codex/', 'openai-codex'),
    ('@google/gemini-cli/', 'gemini'), ('@github/copilot/', 'copilot'),
    ('opencode-ai/', 'opencode'), ('aider/', 'aider'), ('devin-cli/', 'devin'),
)


def identity(args, exe=''):
    if not args:
        return None
    base = Path(args[0].split(' ', 1)[0]).name.lower()
    # Shell commands, prompts, and helper subprocesses are not agent identities.
    if any(arg in ('--help', '--version', 'completion', 'completions',
                   '--sandbox-policy-cwd') for arg in args[1:]):
        return None
    if base in AGENTS:
        return AGENTS[base]
    if base in INTERPRETERS or re.fullmatch(r'python3\.\d+', base):
        # Only a script entrypoint may identify an interpreted CLI; never -c/-e code.
        if len(args) < 2 or args[1].startswith('-'):
            return None
        script = args[1].lower()
        script_base = Path(script).name
        if script_base in AGENTS:
            return AGENTS[script_base]
        for package, key in PACKAGES:
            if package in script:
                return AGENTS[key]
    path = (exe or args[0]).lower()
    # IDE backends stay alive while idle: report them explicitly as services.
    if base.startswith('language_server'):
        if 'antigravity' in path:
            return ('Antigravity', 'antigravity.png')
        if 'windsurf' in path or 'devin' in path:
            return ('Devin', '') if 'devin' in path else ('Windsurf', '')
    if base == 'copilot-language-server':
        return AGENTS['copilot']
    return None


def read_processes(proc_root=Path('/proc')):
    processes = {}
    for entry in proc_root.iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            fields = (entry / 'stat').read_text().rsplit(')', 1)[1].split()
            if fields[0] == 'Z':
                continue
            args = (entry / 'cmdline').read_bytes().decode(errors='replace').rstrip('\0').split('\0')
            if not args or not args[0]:
                continue
            try:
                exe = os.readlink(entry / 'exe')
            except OSError:
                exe = args[0].split(' ', 1)[0]
            processes[int(entry.name)] = {
                'ppid': int(fields[1]), 'tty': int(fields[4]),
                'args': args, 'exe': exe, 'agent': identity(args, exe),
            }
        except (OSError, ValueError, IndexError):
            continue
    return processes


def get_agy_status():
    import time
    state_dir = Path('/tmp/agy_state')
    if not state_dir.exists():
        return None
    latest_state = None
    latest_time = 0
    for f in state_dir.glob('*.json'):
        try:
            data = json.loads(f.read_text())
            if data['timestamp'] > latest_time:
                latest_time = data['timestamp']
                latest_state = data['state']
        except Exception:
            continue
    if latest_time < time.time() - 86400:
        return None
    return latest_state


def ancestors(pid, processes):
    seen = {pid}
    parent = processes[pid]['ppid']
    while parent in processes and parent not in seen:
        seen.add(parent)
        yield processes[parent]
        parent = processes[parent]['ppid']


def summarize(processes):
    agy_status = get_agy_status()
    groups = {}
    for pid, process in processes.items():
        agent = process['agent']
        if not agent:
            continue
        parents = list(ancestors(pid, processes))
        if any(parent['agent'] == agent for parent in parents):
            continue  # Node launcher + native child count as a single session.
        chain = [process] + parents
        editor = any(re.search(r'(?:/|^)(?:code|code-insiders|codium|cursor|antigravity|windsurf|devin-desktop)(?:/|$)', p['exe'].lower())
                     or any(part in p['exe'].lower() for part in ('/.vscode/', '/.vscode-insiders/', '/extensions/'))
                     or '--app=/opt/devin-desktop/' in p['args'][0]
                     for p in chain)
        service = (not process['tty']) and (
            editor or 'app-server' in process['args'][1:]
            or Path(process['exe']).name.startswith(('language_server', 'copilot-language-server')))
        source = ('Editor terminal' if editor else 'Terminal') if process['tty'] else ('Editor' if editor else 'Background')
        
        if source == 'Background':
            continue
            
        name, icon = agent
        state = 'Service running' if service else 'Session running'
        
        if name == 'Antigravity' and not service:
            if agy_status == 'running':
                state = 'Processing'
            elif agy_status == 'idle':
                state = 'Waiting for input'

        key = (name, source, state)
        if key not in groups:
            groups[key] = dict(name=name, icon=icon, source=source, state=state, count=0)
        groups[key]['count'] += 1
    return sorted(groups.values(), key=lambda row: (row['state'] == 'Service running', row['name'], row['source']))


def main():
    try:
        processes = read_processes()
        print(json.dumps({'available': bool(processes), 'agents': summarize(processes)}))
    except OSError:
        print(json.dumps({'available': False, 'agents': []}))


if __name__ == '__main__':
    main()
