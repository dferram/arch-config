#!/usr/bin/env python3
"""
peripherals-status.py
Detects connected external Monitor, Mouse, External Keyboard (e.g. Terport TR69N),
and persists Cooling Base power toggle + 3D Keyboard LED replica state.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

DATA_DIR = Path.home() / ".local" / "share" / "desktop-widgets"
STATE_FILE = DATA_DIR / "setup_state.json"

DEFAULT_STATE = {
    "base": {
        "on": False,
        "uhubctlLocation": "",
        "uhubctlPort": "",
    },
    "replica": {
        "ledOn": True,
        "mode": "rainbow",
        "color": "#bf4148",
        "multiColor": True,
        "speed": 1.0,
        "brightness": 0.9,
    },
}

INTERNAL_NAME_KEYWORDS = (
    "at translated set 2",
    "touchpad",
    "touchscreen",
    "trackpad",
    "stylus",
    "ftsc",
    "bltp",
    "huawei wmi",
    "video bus",
    "power button",
    "lid switch",
    "pc speaker",
    "sof-hda",
    "ydotoold",
)


def load_state():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if STATE_FILE.exists():
        try:
            raw = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                base = dict(DEFAULT_STATE["base"])
                base.update(raw.get("base", {}) if isinstance(raw.get("base"), dict) else {})
                rep = dict(DEFAULT_STATE["replica"])
                rep.update(raw.get("replica", {}) if isinstance(raw.get("replica"), dict) else {})
                return {"base": base, "replica": rep}
        except Exception:
            pass
    return {
        "base": dict(DEFAULT_STATE["base"]),
        "replica": dict(DEFAULT_STATE["replica"]),
    }


def save_state(state):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    tmp.replace(STATE_FILE)


def read_edid_monitor_name(drm_entry):
    edid_path = drm_entry / "edid"
    if not edid_path.exists():
        return ""
    try:
        data = edid_path.read_bytes()
        if len(data) < 128:
            return ""
        for offset in (54, 72, 90, 108):
            block = data[offset : offset + 18]
            if len(block) == 18 and block[0:3] == b"\x00\x00\x00" and block[3] == 0xFC:
                raw = block[5:18].decode("ascii", errors="ignore").split("\n", 1)[0].strip()
                if raw:
                    return raw
    except Exception:
        pass
    return ""


def detect_external_monitor():
    drm_dir = Path("/sys/class/drm")
    connected_outputs = []
    edid_names = {}
    if drm_dir.exists():
        for entry in sorted(drm_dir.iterdir()):
            name = entry.name
            if "-" not in name or not name.startswith("card"):
                continue
            status_file = entry / "status"
            if not status_file.exists():
                continue
            try:
                status = status_file.read_text(encoding="utf-8").strip().lower()
            except Exception:
                continue
            connector = name.split("-", 1)[1]
            if connector.startswith("eDP"):
                continue
            if status == "connected":
                connected_outputs.append(connector)
                edid_name = read_edid_monitor_name(entry)
                if edid_name:
                    edid_names[connector] = edid_name

    if not connected_outputs:
        return {"connected": False, "name": "Monitor", "detail": "Disconnected"}

    primary_conn = connected_outputs[0]
    detail = primary_conn
    disp_name = edid_names.get(primary_conn, primary_conn)

    try:
        res = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True,
            text=True,
            timeout=0.35,
        )
        if res.returncode == 0 and res.stdout.strip():
            mons = json.loads(res.stdout)
            for m in mons:
                m_name = m.get("name", "")
                if m_name in connected_outputs or (not m_name.startswith("eDP") and m_name):
                    w = m.get("width")
                    h = m.get("height")
                    hz = m.get("refreshRate")
                    model = (m.get("model") or "").strip()
                    if model:
                        disp_name = model
                    elif m_name:
                        disp_name = m_name
                    if w and h:
                        hz_txt = f" @ {int(round(hz))}Hz" if hz else ""
                        detail = f"{w}×{h}{hz_txt}"
                    break
    except Exception:
        pass

    return {"connected": True, "name": disp_name, "detail": detail}


def parse_input_devices():
    proc_path = Path("/proc/bus/input/devices")
    if not proc_path.exists():
        return []
    try:
        text = proc_path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return []

    devices = []
    for block in text.strip().split("\n\n"):
        info = {"bus": "", "vendor": "", "product": "", "name": "", "phys": "", "handlers": [], "key_words": 0}
        for line in block.splitlines():
            if line.startswith("I: "):
                m_bus = re.search(r"Bus=([0-9a-fA-F]+)", line)
                m_ven = re.search(r"Vendor=([0-9a-fA-F]+)", line)
                m_prod = re.search(r"Product=([0-9a-fA-F]+)", line)
                if m_bus:
                    info["bus"] = m_bus.group(1).lower()
                if m_ven:
                    info["vendor"] = m_ven.group(1).lower()
                if m_prod:
                    info["product"] = m_prod.group(1).lower()
            elif line.startswith("N: Name="):
                info["name"] = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("P: Phys="):
                info["phys"] = line.split("=", 1)[1].strip()
            elif line.startswith("H: Handlers="):
                info["handlers"] = line.split("=", 1)[1].strip().split()
            elif line.startswith("B: KEY="):
                words = line.split("=", 1)[1].strip().split()
                info["key_words"] = len(words)
        if info["name"]:
            devices.append(info)
    return devices


def clean_dev_name(name, fallback):
    n = re.sub(r"\s+(Keyboard|Mouse|Consumer Control|System Control)$", "", name.strip(), flags=re.IGNORECASE)
    n = re.sub(r"\s+", " ", n).strip()
    return n or fallback


def detect_mouse_and_keyboard():
    devices = parse_input_devices()
    mouse_info = {"connected": False, "name": "Mouse", "transport": ""}
    kbd_info = {"connected": False, "name": "Terport TR69N", "detectedName": "", "transport": ""}

    for dev in devices:
        name_low = dev["name"].lower()
        phys_low = dev["phys"].lower()
        bus = dev["bus"]

        if any(kw in name_low for kw in INTERNAL_NAME_KEYWORDS):
            continue
        if phys_low.startswith(("isa", "i2c-", "pnp", "lnxvideo", "wmi", "alsa")):
            continue

        is_usb = bus == "0003" or "usb-" in phys_low
        is_bt = bus == "0005" or "hci" in phys_low or bool(re.match(r"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$", phys_low))
        if not (is_usb or is_bt):
            continue

        transport = "USB" if is_usb else "BT"
        handlers = dev["handlers"]
        has_mouse = any(h.startswith("mouse") for h in handlers)
        has_kbd = "kbd" in handlers
        has_leds = "leds" in handlers

        if has_mouse and not mouse_info["connected"]:
            mouse_info = {
                "connected": True,
                "name": clean_dev_name(dev["name"], f"{transport} Mouse"),
                "transport": transport,
            }
        elif has_kbd and (has_leds or dev["key_words"] >= 6) and not has_mouse:
            if "consumer control" in name_low or "system control" in name_low:
                continue
            if not kbd_info["connected"]:
                detected = clean_dev_name(dev["name"], f"{transport} Keyboard")
                kbd_info = {
                    "connected": True,
                    "name": "Terport TR69N" if "terport" in name_low else detected,
                    "detectedName": detected,
                    "transport": transport,
                }

    return mouse_info, kbd_info


def try_uhubctl_power(base_cfg, turn_on):
    uhubctl_bin = shutil.which("uhubctl")
    loc = (base_cfg.get("uhubctlLocation") or "").strip()
    port = str(base_cfg.get("uhubctlPort") or "").strip()
    if not uhubctl_bin or not loc or not port:
        return ""
    action = "1" if turn_on else "0"
    try:
        res = subprocess.run(
            [uhubctl_bin, "-l", loc, "-p", port, "-a", action],
            capture_output=True,
            text=True,
            timeout=2.0,
        )
        if res.returncode != 0:
            return (res.stderr or res.stdout or "uhubctl failed").strip()[:120]
    except Exception as exc:
        return str(exc)[:120]
    return ""


def build_status(state, uhubctl_error=""):
    monitor = detect_external_monitor()
    mouse, keyboard = detect_mouse_and_keyboard()
    base_cfg = state["base"]
    uhubctl_bin = shutil.which("uhubctl")
    loc = (base_cfg.get("uhubctlLocation") or "").strip()
    port = str(base_cfg.get("uhubctlPort") or "").strip()

    return {
        "monitor": monitor,
        "mouse": mouse,
        "keyboard": keyboard,
        "base": {
            "on": bool(base_cfg.get("on", False)),
            "uhubctlAvailable": bool(uhubctl_bin),
            "uhubctlConfigured": bool(uhubctl_bin and loc and port),
            "uhubctlError": uhubctl_error,
        },
        "replica": state["replica"],
    }


def main():
    parser = argparse.ArgumentParser(description="Desk peripherals status and replica state helper")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("status")
    sub.add_parser("toggle-base")

    p_rep = sub.add_parser("set-replica")
    p_rep.add_argument("--mode", default=None)
    p_rep.add_argument("--color", default=None)
    p_rep.add_argument("--multi-color", default=None)
    p_rep.add_argument("--speed", type=float, default=None)
    p_rep.add_argument("--brightness", type=float, default=None)
    p_rep.add_argument("--led-on", default=None)

    args = parser.parse_args()
    cmd = args.cmd or "status"
    state = load_state()
    uhubctl_err = ""

    if cmd == "toggle-base":
        next_on = not bool(state["base"].get("on", False))
        state["base"]["on"] = next_on
        save_state(state)
        uhubctl_err = try_uhubctl_power(state["base"], next_on)
    elif cmd == "set-replica":
        rep = state["replica"]
        if args.mode is not None:
            rep["mode"] = args.mode.strip().lower()
        if args.color is not None and re.match(r"^#[0-9a-fA-F]{6}$", args.color.strip()):
            rep["color"] = args.color.strip().lower()
        if args.multi_color is not None:
            rep["multiColor"] = args.multi_color.strip().lower() in ("1", "true", "yes", "on")
        if args.speed is not None:
            rep["speed"] = max(0.2, min(3.0, float(args.speed)))
        if args.brightness is not None:
            rep["brightness"] = max(0.0, min(1.0, float(args.brightness)))
        if args.led_on is not None:
            rep["ledOn"] = args.led_on.strip().lower() in ("1", "true", "yes", "on")
        save_state(state)

    print(json.dumps(build_status(state, uhubctl_err), ensure_ascii=False))


if __name__ == "__main__":
    main()
