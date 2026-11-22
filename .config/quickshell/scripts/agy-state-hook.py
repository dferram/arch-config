#!/usr/bin/env python3
import sys
import json
import os
import subprocess
import time

STATE_DIR = "/tmp/agy_state"


def notify_idle(payload: dict) -> None:
    workspace_paths = payload.get("workspacePaths") or []
    proj = ""
    if workspace_paths and isinstance(workspace_paths, list):
        name = os.path.basename(os.path.normpath(str(workspace_paths[0])))
        if name and name != "ferram":
            proj = name

    title = f"Antigravity • {proj}" if proj else "Antigravity"
    error = (payload.get("error") or "").strip()
    reason = payload.get("terminationReason") or ""
    if error:
        body = f"Error: {error[:100]}"
        urgency = "critical"
    elif reason == "max_steps_exceeded":
        body = "Límite de pasos alcanzado"
        urgency = "normal"
    else:
        body = "Respuesta lista"
        urgency = "normal"

    env = os.environ.copy()
    if not env.get("DBUS_SESSION_BUS_ADDRESS"):
        env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{os.getuid()}/bus"

    try:
        subprocess.run(
            ["notify-send", "-a", "Antigravity", "-u", urgency, "-t", "6000", title, body],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
            check=False,
        )
    except Exception:
        pass


def main():
    if len(sys.argv) < 2:
        return

    event = sys.argv[1]  # "running" or "idle"

    # Read the JSON payload from stdin
    try:
        payload_str = sys.stdin.read()
        payload = json.loads(payload_str)
    except Exception:
        payload = {}

    conversation_id = payload.get("conversationId", "unknown")

    os.makedirs(STATE_DIR, exist_ok=True)
    state_file = os.path.join(STATE_DIR, f"{conversation_id}.json")

    state_data = {
        "state": event,
        "timestamp": time.time(),
        "conversation_id": conversation_id,
    }

    # Write state
    with open(state_file, "w") as f:
        json.dump(state_data, f)

    if event == "idle":
        notify_idle(payload)

    # Output required JSON to stdout so Antigravity doesn't error
    print("{}")


if __name__ == "__main__":
    main()
