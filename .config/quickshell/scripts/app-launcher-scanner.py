#!/usr/bin/env python3
"""
app-launcher-scanner.py: Indexes all desktop applications on the system
and provides fast lookup and launching.
"""
import os
import sys
import json
import subprocess
import re

APP_DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    "/usr/local/share/applications",
    "/usr/share/applications"
]

# Include any extra XDG_DATA_DIRS application directories
for _xdg in os.environ.get("XDG_DATA_DIRS", "").split(":"):
    if _xdg:
        _app_dir = os.path.join(_xdg, "applications")
        if _app_dir not in APP_DIRS and os.path.isdir(_app_dir):
            APP_DIRS.append(_app_dir)


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

def scan_apps():
    apps = []
    seen_names = set()
    seen_execs = set()

    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for root_dir, _, files in os.walk(d):
            for f in files:
                if not f.endswith(".desktop") or f in IGNORED_DESKTOP_IDS:
                    continue
                fpath = os.path.join(root_dir, f)
                
                name, exec_cmd, icon, nodisplay, comment, categories = "", "", "", False, "", ""
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
                                elif line.startswith("Terminal="):
                                    terminal = (line[9:].strip().lower() == "true")
                except Exception:
                    continue

                if nodisplay or not name or not exec_cmd:
                    continue

                # Clean exec command (remove %f, %u, %F, %U, and Flatpak @@u @@ markers)
                clean_exec = re.sub(r"@@.*?@@", "", exec_cmd)
                clean_exec = re.sub(r"@@[a-zA-Z]*", "", clean_exec)
                clean_exec = re.sub(r"%[a-zA-Z]", "", clean_exec).strip()

                # Deduplicate identical app names
                key = name.lower()
                if key in seen_names:
                    continue
                seen_names.add(key)

                apps.append({
                    "id": f,
                    "name": name,
                    "exec": clean_exec,
                    "icon": icon,
                    "comment": comment,
                    "categories": categories,
                    "terminal": terminal
                })

    # Sort alphabetically
    apps.sort(key=lambda a: a["name"].lower())
    return apps

def launch_app(desktop_file, exec_cmd, terminal=False):
    # Try gtk-launch first if desktop file is valid
    if desktop_file:
        try:
            desktop_id = os.path.basename(desktop_file)
            res = subprocess.run(["gtk-launch", desktop_id], capture_output=True)
            if res.returncode == 0:
                return True
        except Exception:
            pass

    # Fallback to direct exec
    if not exec_cmd:
        return False

    cmd = exec_cmd
    if terminal:
        cmd = f"kitty -e {cmd}"

    try:
        subprocess.Popen(cmd, shell=True, start_new_session=True)
        return True
    except Exception:
        return False

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "launch":
        # Format: python3 app-launcher-scanner.py launch <desktop_id> <exec_cmd> <is_terminal>
        desktop_id = sys.argv[2] if len(sys.argv) > 2 else ""
        exec_cmd = sys.argv[3] if len(sys.argv) > 3 else ""
        is_term = sys.argv[4].lower() == "true" if len(sys.argv) > 4 else False
        launch_app(desktop_id, exec_cmd, is_term)
    else:
        print(json.dumps(scan_apps()))
