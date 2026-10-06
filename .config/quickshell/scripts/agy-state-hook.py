#!/usr/bin/env python3
import sys
import json
import os
import time

STATE_DIR = "/tmp/agy_state"

def main():
    if len(sys.argv) < 2:
        return
        
    event = sys.argv[1] # "running" or "idle"
    
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
        "conversation_id": conversation_id
    }
    
    # Write state
    with open(state_file, "w") as f:
        json.dump(state_data, f)
        
    # Output required JSON to stdout so Antigravity doesn't error
    print("{}")

if __name__ == '__main__':
    main()
