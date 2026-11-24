#!/usr/bin/env python3
"""
peripherals-status.py
Passively detects connected external Monitor, Mouse, and External Keyboard (Terport TR69N)
and reads the keyboard's live hardware LED configuration block (page 0xb6, read-only)
to reflect its active mode, color, brightness, and speed in the 3D Desk Setup widget.
"""

import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import time

TERPORT_VID = "258a"
TERPORT_PID = "0049"

# Hardware color palette (GRB wiring in 0xB800: 0..6 single colors, 7 = Full RGB)
# Cycle on keyboard: 7(RGB) -> 0(Green) -> 1(Yellow) -> 2(Red) -> 3(Pink) -> 4(Dark Blue) -> 5(Light Blue) -> 6(White)
HW_COLOR_MAP = {
    0: ("#30d158", "Green"),
    1: ("#ffd60a", "Yellow"),
    2: ("#ff2d3b", "Red"),
    3: ("#ff2d87", "Pink"),
    4: ("#1d4ed8", "Dark Blue"),
    5: ("#38bdf8", "Light Blue"),
    6: ("#f1f5f9", "White"),
    7: ("#f1f5f9", "Full RGB"),
}

# Hardware mode ID (0x01..0x14) -> (3D replica mode id, human label)
HW_MODE_MAP = {
    0x01: ("static", "Static Solid"),
    0x02: ("breathing", "Breathing"),
    0x03: ("breathing_cycle", "RGB Pulse"),
    0x04: ("col_scan", "Column by Column"),
    0x05: ("vertical_wave", "Top to Bottom"),
    0x06: ("pinwheel", "Continuous Spin"),
    0x07: ("reactive_cluster", "Reactive Cluster"),
    0x08: ("starlight", "Starlight"),
    0x09: ("inverted_reactive", "Solid Inverse Key"),
    0x0A: ("marquee", "Marquee Snake"),
    0x0B: ("horizontal_wave", "Horizontal Wave"),
    0x0C: ("reactive_typing", "Single Reactive Key"),
    0x0D: ("sine_wave", "Battle Rope Wave"),
    0x0E: ("wide_sweep", "Wide Side Sweep"),
    0x0F: ("radar", "Radar Aurora"),
    0x10: ("vertical_wave", "Vertical Wave"),
    0x11: ("ripple", "Blooming Rings"),
    0x12: ("collision", "Diagonal Clash"),
    0x13: ("center_split", "Center Split"),
    0x14: ("crosshair", "Reactive Crosshair"),
}

# Modes locked to Full RGB in firmware (0x3474 check)
ALWAYS_MULTICOLOR_MODES = {0x03, 0x0F, 0x10, 0x11}

SPEED_MAP = [0.4, 0.7, 1.0, 1.4, 1.9]

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


def _ioc(direction, ioctl_type, nr, size):
    return (direction << 30) | (size << 16) | (ord(ioctl_type) << 8) | nr


def _hidiocsfeature(length):
    return _ioc(3, "H", 0x06, length)


def _hidiocgfeature(length):
    return _ioc(3, "H", 0x07, length)


def find_terport_hidraw():
    hidraw_dir = Path("/sys/class/hidraw")
    if not hidraw_dir.exists():
        return None
    target_id = f"0003:0000{TERPORT_VID.upper()}:0000{TERPORT_PID.upper()}"
    for entry in sorted(hidraw_dir.iterdir()):
        uevent_path = entry / "device" / "uevent"
        desc_path = entry / "device" / "report_descriptor"
        try:
            uevent = uevent_path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        if target_id not in uevent.upper():
            continue
        try:
            desc = desc_path.read_bytes()
        except Exception:
            desc = b""
        if b"\x85\x05" in desc and b"\x85\x06" in desc:
            return f"/dev/{entry.name}"
    return None


def read_keyboard_hardware_state():
    """Read-only query of page 0xb6 on Terport TR69N to reflect active mode/color/speed/brightness."""
    default_rep = {
        "ledOn": True,
        "mode": "rainbow",
        "modeLabel": "Spectrum Wave",
        "color": "#f1f5f9",
        "colorLabel": "Full RGB",
        "multiColor": True,
        "speed": 1.0,
        "brightness": 1.0,
        "hwModeId": 0x0B,
    }
    hidraw = find_terport_hidraw()
    if not hidraw:
        return default_rep

    try:
        fd = os.open(hidraw, os.O_RDWR)
    except OSError:
        return default_rep

    try:
        cmd = bytearray([0x05, 0x83, 0xB6, 0x00, 0x00, 0x00])
        fcntl.ioctl(fd, _hidiocsfeature(6), cmd)
        time.sleep(0.012)
        buf = bytearray(1032)
        buf[0] = 0x06
        n = fcntl.ioctl(fd, _hidiocgfeature(1032), buf)
        if n < 0x50 or buf[0x0E] != 0x5A or buf[0x0F] != 0xA5:
            return default_rep

        is_game_mode = buf[0x14] != 0
        if is_game_mode:
            game_id = buf[0x16]
            b1 = buf[0x60 + max(0, min(4, game_id - 0x20))]
            brt_idx = max(0, min(4, b1 & 0x0F))
            return {
                "ledOn": brt_idx > 0,
                "mode": "wasd_gaming",
                "modeLabel": f"Game Profile {max(1, game_id - 0x1F)}",
                "color": "#ff2d3b",
                "colorLabel": "Gaming Zone",
                "multiColor": True,
                "speed": 1.0,
                "brightness": brt_idx / 4.0,
                "hwModeId": game_id,
            }

        hw_mode = buf[0x15]
        if hw_mode < 1 or hw_mode > 20:
            hw_mode = 0x0B

        mode_id, mode_label = HW_MODE_MAP.get(hw_mode, ("rainbow", "Spectrum Wave"))
        b0 = buf[0x24 + 2 * hw_mode]
        b1 = buf[0x25 + 2 * hw_mode]

        color_idx = b0 & 0x07
        brt_idx = max(0, min(4, b1 & 0x0F))
        spd_idx = max(0, min(4, (b1 >> 4) & 0x07))

        is_multi = (
            hw_mode in ALWAYS_MULTICOLOR_MODES
            or color_idx == 7
            or (b0 & 0x80) != 0
        )
        color_hex, color_label = HW_COLOR_MAP.get(color_idx, ("#f1f5f9", "Full RGB"))
        if is_multi:
            color_label = "Full RGB"

        return {
            "ledOn": brt_idx > 0,
            "mode": mode_id if brt_idx > 0 else "off",
            "modeLabel": mode_label if brt_idx > 0 else "Lights Off",
            "color": color_hex,
            "colorLabel": color_label,
            "multiColor": is_multi,
            "speed": SPEED_MAP[spd_idx],
            "brightness": brt_idx / 4.0,
            "hwModeId": hw_mode,
        }
    except Exception:
        return default_rep
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


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
                raw = (
                    block[5:18]
                    .decode("ascii", errors="ignore")
                    .split("\n", 1)[0]
                    .strip()
                )
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
                if m_name in connected_outputs or (
                    not m_name.startswith("eDP") and m_name
                ):
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
        info = {
            "bus": "",
            "vendor": "",
            "product": "",
            "name": "",
            "phys": "",
            "handlers": [],
            "key_words": 0,
        }
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
    n = re.sub(
        r"\s+(Keyboard|Mouse|Consumer Control|System Control)$",
        "",
        name.strip(),
        flags=re.IGNORECASE,
    )
    n = re.sub(r"\s+", " ", n).strip()
    return n or fallback


def detect_mouse_and_keyboard():
    devices = parse_input_devices()
    mouse_info = {"connected": False, "name": "Mouse", "transport": ""}
    kbd_info = {
        "connected": False,
        "name": "Terport TR69N",
        "detectedName": "",
        "transport": "",
    }
    fallback_mouse = None

    for dev in devices:
        name_low = dev["name"].lower()
        phys_low = dev["phys"].lower()
        bus = dev["bus"]

        if any(kw in name_low for kw in INTERNAL_NAME_KEYWORDS):
            continue
        if phys_low.startswith(("isa", "i2c-", "pnp", "lnxvideo", "wmi", "alsa")):
            continue

        is_usb = bus == "0003" or "usb-" in phys_low
        is_bt = (
            bus == "0005"
            or "hci" in phys_low
            or bool(re.match(r"^[0-9a-f]{2}(:[0-9a-f]{2}){5}$", phys_low))
        )
        if not (is_usb or is_bt):
            continue

        transport = "USB" if is_usb else "BT"
        handlers = dev["handlers"]
        has_mouse = any(h.startswith("mouse") for h in handlers)
        has_kbd = "kbd" in handlers
        has_leds = "leds" in handlers
        is_terport_usb = dev["vendor"] == TERPORT_VID and dev["product"] == TERPORT_PID

        if has_mouse:
            candidate = {
                "connected": True,
                "name": clean_dev_name(dev["name"], f"{transport} Mouse"),
                "transport": transport,
            }
            if "keyboard" in name_low or is_terport_usb:
                if fallback_mouse is None:
                    fallback_mouse = candidate
            elif not mouse_info["connected"]:
                mouse_info = candidate
        elif has_kbd and (has_leds or dev["key_words"] >= 6):
            if "consumer control" in name_low or "system control" in name_low:
                continue
            if not kbd_info["connected"]:
                detected = clean_dev_name(dev["name"], f"{transport} Keyboard")
                is_terport = "terport" in name_low or is_terport_usb
                kbd_info = {
                    "connected": True,
                    "name": "Terport TR69N" if is_terport else detected,
                    "detectedName": detected,
                    "transport": transport,
                }

    if not mouse_info["connected"] and fallback_mouse is not None:
        mouse_info = fallback_mouse

    return mouse_info, kbd_info


def main():
    monitor = detect_external_monitor()
    mouse, keyboard = detect_mouse_and_keyboard()
    base_active = bool(
        monitor["connected"] or keyboard["connected"] or mouse["connected"]
    )
    replica = (
        read_keyboard_hardware_state()
        if keyboard["connected"]
        else {
            "ledOn": False,
            "mode": "off",
            "modeLabel": "Unplugged",
            "color": "#f1f5f9",
            "colorLabel": "Off",
            "multiColor": True,
            "speed": 1.0,
            "brightness": 0.0,
        }
    )
    status = {
        "monitor": monitor,
        "mouse": mouse,
        "keyboard": keyboard,
        "base": {
            "on": base_active,
        },
        "replica": replica,
    }
    print(json.dumps(status, ensure_ascii=False))


if __name__ == "__main__":
    main()
