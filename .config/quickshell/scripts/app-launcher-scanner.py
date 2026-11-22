#!/usr/bin/env python3
"""
app-launcher-scanner.py: Indexes all desktop applications on the system,
tracks launch frecency, and provides fast lookup and launching.
"""
import json
import os
import re
import subprocess
import sys
import time

APP_DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    "/usr/local/share/applications",
    "/usr/share/applications",
]

for _xdg in os.environ.get("XDG_DATA_DIRS", "").split(":"):
    if _xdg:
        _app_dir = os.path.join(_xdg, "applications")
        if _app_dir not in APP_DIRS and os.path.isdir(_app_dir):
            APP_DIRS.append(_app_dir)

HISTORY_FILE = os.path.expanduser("~/.local/state/quickshell-launcher-history.json")

IGNORED_DESKTOP_IDS = {
    "bssh.desktop",
    "bvnc.desktop",
    "avahi-discover.desktop",
    "qv4l2.desktop",
    "qvidcap.desktop",
    "lstopo.desktop",
    "rofi-theme-selector.desktop",
    "spotify-launcher.desktop",
}


def load_history() -> dict:
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as fp:
            data = json.load(fp)
            return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def record_launch(desktop_id: str) -> None:
    if not desktop_id:
        return
    history = load_history()
    entry = history.get(desktop_id)
    if not isinstance(entry, dict):
        entry = {"count": 0, "last_used": 0}
    entry["count"] = int(entry.get("count", 0)) + 1
    entry["last_used"] = int(time.time())
    history[desktop_id] = entry
    try:
        os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
        with open(HISTORY_FILE, "w", encoding="utf-8") as fp:
            json.dump(history, fp, indent=2)
    except Exception:
        pass


def compute_frecency(entry: dict | None, now: float) -> float:
    if not isinstance(entry, dict):
        return 0.0
    count = int(entry.get("count", 0))
    last_used = float(entry.get("last_used", 0))
    if count <= 0:
        return 0.0
    age_hours = max(0.0, (now - last_used) / 3600.0)
    if age_hours < 4:
        recency_mult = 4.0
    elif age_hours < 24:
        recency_mult = 2.5
    elif age_hours < 24 * 7:
        recency_mult = 1.5
    else:
        recency_mult = 0.8
    return round(min(40.0, count * 4.0 * recency_mult), 2)


def scan_apps():
    apps = []
    seen_names = set()
    history = load_history()
    now = time.time()

    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for root_dir, _, files in os.walk(d):
            for f in files:
                if not f.endswith(".desktop") or f in IGNORED_DESKTOP_IDS:
                    continue
                fpath = os.path.join(root_dir, f)

                name, exec_cmd, icon, nodisplay, comment, categories, keywords = "", "", "", False, "", "", ""
                terminal = False
                try:
                    with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
                        in_entry = False
                        for line in fp:
                            line = line.strip()
                            if line == "[Desktop Entry]":
                                in_entry = True
                                continue
                            elif line.startswith("[") and in_entry:
                                break
                            if in_entry:
                                if line.startswith("Name=") and not name:
                                    name = line[5:].strip()
                                elif line.startswith("Exec=") and not exec_cmd:
                                    exec_cmd = line[5:].strip()
                                elif line.startswith("Icon=") and not icon:
                                    icon = line[5:].strip()
                                elif line.startswith("NoDisplay="):
                                    nodisplay = (line[10:].strip().lower() == "true")
                                elif line.startswith("Comment=") and not comment:
                                    comment = line[8:].strip()
                                elif line.startswith("Categories=") and not categories:
                                    categories = line[11:].strip()
                                elif line.startswith("Keywords=") and not keywords:
                                    keywords = line[9:].replace(";", " ").strip()
                                elif line.startswith("Terminal="):
                                    terminal = (line[9:].strip().lower() == "true")
                except Exception:
                    continue

                if nodisplay or not name or not exec_cmd:
                    continue

                clean_exec = re.sub(r"@@.*?@@", "", exec_cmd)
                clean_exec = re.sub(r"@@[a-zA-Z]*", "", clean_exec)
                clean_exec = re.sub(r"%[a-zA-Z]", "", clean_exec).strip()

                key = name.lower()
                if key in seen_names:
                    continue
                seen_names.add(key)

                hist_entry = history.get(f)
                apps.append({
                    "id": f,
                    "name": name,
                    "exec": clean_exec,
                    "icon": icon,
                    "comment": comment,
                    "keywords": keywords,
                    "categories": categories,
                    "terminal": terminal,
                    "frecency": compute_frecency(hist_entry, now),
                    "lastUsed": int(hist_entry.get("last_used", 0)) if isinstance(hist_entry, dict) else 0,
                })

    apps.sort(key=lambda a: a["name"].lower())
    return apps


def launch_app(desktop_file, exec_cmd, terminal=False):
    desktop_id = os.path.basename(desktop_file) if desktop_file else ""
    record_launch(desktop_id)

    if terminal and exec_cmd:
        try:
            subprocess.Popen(
                f"kitty -e {exec_cmd}",
                shell=True,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return True
        except Exception:
            pass

    if desktop_id:
        try:
            res = subprocess.run(
                ["gtk-launch", desktop_id],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=0.4,
            )
            if res.returncode == 0:
                return True
        except subprocess.TimeoutExpired:
            return True
        except Exception:
            pass

    if not exec_cmd:
        return False

    try:
        subprocess.Popen(
            exec_cmd,
            shell=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return True
    except Exception:
        return False


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "launch":
        desktop_id = sys.argv[2] if len(sys.argv) > 2 else ""
        exec_cmd = sys.argv[3] if len(sys.argv) > 3 else ""
        is_term = sys.argv[4].lower() == "true" if len(sys.argv) > 4 else False
        launch_app(desktop_id, exec_cmd, is_term)
    else:
        print(json.dumps(scan_apps()))
