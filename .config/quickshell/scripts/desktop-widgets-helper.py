#!/usr/bin/env python3
"""
desktop-widgets-helper.py
Backend service helper for Quickshell Apple Sonoma Desktop Widgets:
- Photo albums, multi-album selection, Dolphin integration, 1-min rotation
- Notes persistence (read/write)
- Grid layout coordinates persistence and dynamic widget management
"""

import sys
import os
import copy
import json
import hashlib
import random
import subprocess
import fcntl
import shutil
from datetime import datetime
from pathlib import Path

HOME = Path.home()
DATA_DIR = HOME / ".local" / "share" / "desktop-widgets"
CONFIG_FILE = DATA_DIR / "photos_config.json"
BAK_FILE = DATA_DIR / "photos_config.json.bak"
LOCK_FILE = DATA_DIR / "photos_config.lock"
NOTES_FILE = DATA_DIR / "notes.json"
GRID_FILE = DATA_DIR / "grid_positions.json"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".JPG", ".JPEG", ".PNG", ".WEBP"}

PICS = HOME / "Pictures"

DEFAULT_CONFIG = {
    "1": {
        "mode": "folders",
        "folders": [str(PICS)],
        "folder": str(PICS),
        "files": [],
        "current_index": 0,
        "recursive": True,
        "shuffle": True,
        "interval": 30,
        "fit_mode": "crop"
    },
    "2": {
        "mode": "folders",
        "folders": [str(PICS)],
        "folder": str(PICS),
        "files": [],
        "current_index": 0,
        "recursive": True,
        "shuffle": True,
        "interval": 30,
        "fit_mode": "crop"
    },
    "3": {
        "mode": "folders",
        "folders": [str(PICS / "Wallpapers")],
        "folder": str(PICS / "Wallpapers"),
        "files": [],
        "current_index": 0,
        "recursive": True,
        "shuffle": True,
        "interval": 30,
        "fit_mode": "crop"
    },
    "4": {
        "mode": "folders",
        "folders": [str(PICS)],
        "folder": str(PICS),
        "files": [],
        "current_index": 0,
        "recursive": True,
        "shuffle": True,
        "interval": 30,
        "fit_mode": "crop"
    },
    "5": {
        "mode": "folders",
        "folders": [str(PICS / "Wallpapers")],
        "folder": str(PICS / "Wallpapers"),
        "files": [],
        "current_index": 0,
        "recursive": True,
        "shuffle": True,
        "interval": 30,
        "fit_mode": "crop"
    }
}

DEFAULT_NOTES = {
    "title": "Quick Notes",
    "content": "• Apple Sonoma desktop widgets active.\n• Drag & drop widgets anywhere on the grid.\n• Click any photo widget to select multiple albums or open Dolphin.\n• Wallpaper-adaptive liquid glass theming enabled.",
    "updated_at": datetime.now().strftime("%d/%m/%Y %H:%M")
}

DEFAULT_GRID = {
    # Workspace 1: Daily Essentials & Productivity
    "clock":      { "col": 0, "row": 0, "colSpan": 1, "rowSpan": 1, "type": "clock",      "workspace": 1 },
    "battery":    { "col": 1, "row": 0, "colSpan": 1, "rowSpan": 1, "type": "battery",    "workspace": 1 },
    "calendar":   { "col": 0, "row": 1, "colSpan": 1, "rowSpan": 1, "type": "calendar",   "workspace": 1 },
    "reminders":  { "col": 1, "row": 1, "colSpan": 1, "rowSpan": 1, "type": "reminders",  "workspace": 1 },
    "notes":      { "col": 0, "row": 2, "colSpan": 1, "rowSpan": 1, "type": "notes",      "workspace": 1 },
    "screentime": { "col": 1, "row": 2, "colSpan": 1, "rowSpan": 1, "type": "screentime", "workspace": 1 },
    "photo1":     { "col": 4, "row": 0, "colSpan": 2, "rowSpan": 2, "type": "photo1",     "workspace": 1 },
    "photo2":     { "col": 4, "row": 2, "colSpan": 2, "rowSpan": 2, "type": "photo2",     "workspace": 1 },

    # Workspace 2: Cinematic Premiere & Concert Countdowns
    "doomsday":   { "col": 1, "row": 1, "colSpan": 2, "rowSpan": 1, "type": "doomsday",   "workspace": 2 },
    "nsqk":       { "col": 3, "row": 1, "colSpan": 2, "rowSpan": 1, "type": "nsqk",       "workspace": 2 },
    "photo5":     { "col": 2, "row": 2, "colSpan": 2, "rowSpan": 2, "type": "photo5",     "workspace": 2 },

    # Workspace 3: Sports, Developer & Media Hub
    "f1":         { "col": 1, "row": 0, "colSpan": 2, "rowSpan": 1, "type": "f1",         "workspace": 3 },
    "nba":        { "col": 3, "row": 0, "colSpan": 2, "rowSpan": 1, "type": "nba",        "workspace": 3 },
    "github":     { "col": 1, "row": 1, "colSpan": 2, "rowSpan": 2, "type": "github",     "workspace": 3 },
    "photo3":     { "col": 3, "row": 1, "colSpan": 2, "rowSpan": 2, "type": "photo3",     "workspace": 3 },
    "photo4":     { "col": 1, "row": 3, "colSpan": 2, "rowSpan": 1, "type": "photo4",     "workspace": 3 },
    "leetcode":   { "col": 3, "row": 3, "colSpan": 1, "rowSpan": 1, "type": "leetcode",   "workspace": 3 },
    "agenda":     { "col": 4, "row": 2, "colSpan": 1, "rowSpan": 1, "type": "agenda",     "workspace": 3 },
    "focus":      { "col": 5, "row": 2, "colSpan": 1, "rowSpan": 1, "type": "focus",      "workspace": 3 }
}

def get_wayland_env():
    env = os.environ.copy()
    env["GDK_BACKEND"] = "wayland"
    if "WAYLAND_DISPLAY" not in env:
        env["WAYLAND_DISPLAY"] = "wayland-1"
    if "XDG_RUNTIME_DIR" not in env:
        env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
    return env

def ensure_data():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not CONFIG_FILE.exists():
        save_config(DEFAULT_CONFIG)
    if not NOTES_FILE.exists():
        save_notes(DEFAULT_NOTES)
    if not GRID_FILE.exists():
        save_grid(DEFAULT_GRID)

def load_config():
    ensure_data()
    # Attempt to load CONFIG_FILE, falling back to BAK_FILE if corrupted or unreadable
    for attempt_path in (CONFIG_FILE, BAK_FILE):
        if attempt_path.exists():
            try:
                with open(attempt_path, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
                    if isinstance(cfg, dict):
                        for k, v in DEFAULT_CONFIG.items():
                            if k not in cfg or not isinstance(cfg[k], dict):
                                cfg[k] = v.copy()
                            else:
                                if "recursive" not in cfg[k]:
                                    cfg[k]["recursive"] = True
                                if "shuffle" not in cfg[k]:
                                    cfg[k]["shuffle"] = True
                                if "interval" not in cfg[k]:
                                    cfg[k]["interval"] = 30
                                if "fit_mode" not in cfg[k]:
                                    cfg[k]["fit_mode"] = "crop"
                        return cfg
            except Exception:
                continue
    return DEFAULT_CONFIG.copy()

def save_config(cfg):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    pid = os.getpid()
    tmp = DATA_DIR / f"photos_config.{pid}.tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, CONFIG_FILE)
        shutil.copy2(CONFIG_FILE, BAK_FILE)
    except Exception:
        pass
    finally:
        if tmp.exists():
            try:
                tmp.unlink()
            except Exception:
                pass

def atomic_update_config(widget_id: str, update_fn):
    """Safely and atomically update widget configuration under exclusive file lock."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(LOCK_FILE, "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        try:
            cfg = load_config()
            w_cfg = cfg.get(widget_id, copy.deepcopy(DEFAULT_CONFIG.get(widget_id, DEFAULT_CONFIG["1"])))
            update_fn(w_cfg)
            cfg[widget_id] = w_cfg
            save_config(cfg)
        finally:
            fcntl.flock(lf, fcntl.LOCK_UN)

def load_notes():
    ensure_data()
    try:
        with open(NOTES_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data
    except Exception:
        return DEFAULT_NOTES.copy()

def save_notes(notes):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = NOTES_FILE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(notes, f, indent=2, ensure_ascii=False)
    tmp.replace(NOTES_FILE)

def load_grid():
    ensure_data()
    try:
        with open(GRID_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict):
                return data
            return DEFAULT_GRID.copy()
    except Exception:
        return DEFAULT_GRID.copy()

def save_grid(grid):
    if not isinstance(grid, dict) or len(grid) == 0:
        return
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = GRID_FILE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(grid, f, indent=2, ensure_ascii=False)
    tmp.replace(GRID_FILE)

def list_user_albums():
    """Returns a comprehensive tree-ordered list of image folders found in ~/Pictures and subdirectories."""
    pics = HOME / "Pictures"
    albums = []
    
    if not pics.exists():
        return albums

    # Traverse directory tree
    for root, dirs, files in os.walk(pics, followlinks=True):
        # Exclude hidden directories like .git, .thumbnails, etc.
        dirs[:] = sorted([d for d in dirs if not d.startswith('.')])
        p = Path(root)
        
        direct_imgs = sum(1 for f in files if Path(f).suffix in IMAGE_EXTS)
        
        # Calculate recursive total count
        sub_count = 0
        for sub_root, sub_dirs, sub_files in os.walk(p, followlinks=True):
            sub_dirs[:] = [sd for sd in sub_dirs if not sd.startswith('.')]
            sub_count += sum(1 for sf in sub_files if Path(sf).suffix in IMAGE_EXTS)
            
        if sub_count > 0:
            if p == pics:
                disp = "Pictures (All Photos)"
                short = "Pictures"
                depth = 0
            else:
                try:
                    rel = p.relative_to(pics)
                    disp = " › ".join(rel.parts)
                    short = p.name
                    depth = len(rel.parts)
                except Exception:
                    disp = p.name
                    short = p.name
                    depth = 1

            albums.append({
                "name": disp,
                "shortName": short,
                "path": str(p.resolve()),
                "count": direct_imgs,
                "totalCount": sub_count,
                "depth": depth,
                "hasChildren": len(dirs) > 0
            })

    # Sort albums naturally so hierarchy is clean and logical
    albums.sort(key=lambda x: x["name"].lower())
    return albums

def scan_images_for_widget(w_cfg):
    mode = w_cfg.get("mode", "folders")
    recursive = w_cfg.get("recursive", True)
    photos = []
    album_name = "Photos"

    if mode == "files":
        file_list = w_cfg.get("files", [])
        for p in file_list:
            pth = Path(p)
            if pth.is_file() and pth.suffix in IMAGE_EXTS:
                photos.append(str(pth.resolve()))
        album_name = f"Selection ({len(photos)})"
    else:
        # Check for multiple folders
        folders = w_cfg.get("folders", [])
        if not folders:
            single = w_cfg.get("folder", str(HOME / "Pictures"))
            folders = [single] if single else []

        valid_folders = [Path(f) for f in folders if Path(f).is_dir()]
        if not valid_folders:
            valid_folders = [HOME / "Pictures"]

        found = []
        for folder in valid_folders:
            try:
                if recursive:
                    for root, dirs, files in os.walk(folder, followlinks=True):
                        dirs[:] = sorted([d for d in dirs if not d.startswith('.')])
                        for item in sorted(files):
                            if Path(item).suffix in IMAGE_EXTS:
                                found.append(str((Path(root) / item).resolve()))
                else:
                    for item in sorted(folder.iterdir(), key=lambda x: x.name.lower()):
                        if item.is_file() and item.suffix in IMAGE_EXTS:
                            found.append(str(item.resolve()))
            except Exception:
                pass

        # Deduplicate while preserving natural alphabetical order
        seen = set()
        deduped = []
        for p in found:
            if p not in seen:
                seen.add(p)
                deduped.append(p)

        # Natural alphabetical sort (NEVER deterministic MD5 hash sort)
        deduped.sort(key=lambda x: x.lower())

        if not deduped:
            wall_dir = HOME / "Pictures" / "Wallpapers"
            if wall_dir.exists():
                for item in sorted(wall_dir.iterdir()):
                    if item.is_file() and item.suffix in IMAGE_EXTS:
                        deduped.append(str(item.resolve()))

        photos = deduped
        if len(valid_folders) == 1:
            base_name = valid_folders[0].name or "Pictures"
            if recursive and valid_folders[0] == HOME / "Pictures":
                album_name = "All Photos"
            else:
                album_name = base_name
        elif len(valid_folders) > 1:
            album_name = f"{valid_folders[0].name} + {len(valid_folders)-1} albums"

    return photos, album_name

def get_widget_state(widget_id: str, requested_photo: str = None, requested_index: int = None):
    cfg = load_config()
    w_cfg = cfg.get(widget_id, DEFAULT_CONFIG.get(widget_id, DEFAULT_CONFIG["1"]))
    photos, album_name = scan_images_for_widget(w_cfg)
    total = len(photos)

    is_shuffle = w_cfg.get("shuffle", True)

    if total == 0:
        cur_idx = 0
        cur_photo = ""
    elif requested_photo and requested_photo in photos:
        cur_photo = requested_photo
        cur_idx = photos.index(requested_photo)
    elif requested_index is not None and 0 <= requested_index < total:
        cur_idx = requested_index
        cur_photo = photos[cur_idx]
    elif is_shuffle:
        # Truly random photo selection on initial load / state fetch
        cur_idx = random.randint(0, total - 1)
        cur_photo = photos[cur_idx]
    else:
        # Sequential mode fallback to saved index
        cur_idx = w_cfg.get("current_index", 0) % total
        cur_photo = photos[cur_idx]

    folders = w_cfg.get("folders", [w_cfg.get("folder", str(HOME / "Pictures"))])

    photo_subfolder = ""
    photo_filename = ""
    if cur_photo:
        p_obj = Path(cur_photo)
        photo_filename = p_obj.name
        try:
            for f in folders:
                f_path = Path(f)
                if cur_photo.startswith(str(f_path.resolve())):
                    rel = p_obj.parent.relative_to(f_path)
                    if str(rel) != ".":
                        photo_subfolder = " › ".join(rel.parts)
                    break
            if not photo_subfolder and len(folders) > 1:
                photo_subfolder = p_obj.parent.name
        except Exception:
            photo_subfolder = p_obj.parent.name

    return {
        "id": widget_id,
        "album_name": album_name,
        "mode": w_cfg.get("mode", "folders"),
        "folders": folders,
        "folder": folders[0] if folders else str(HOME / "Pictures"),
        "recursive": w_cfg.get("recursive", True),
        "shuffle": is_shuffle,
        "interval": w_cfg.get("interval", 30),
        "fit_mode": w_cfg.get("fit_mode", "crop"),
        "total": total,
        "current_index": cur_idx,
        "current_photo": cur_photo,
        "photo_filename": photo_filename,
        "photo_subfolder": photo_subfolder
    }

def cycle_widget(widget_id: str, step: int, current_photo: str = ""):
    cfg = load_config()
    w_cfg = cfg.get(widget_id, DEFAULT_CONFIG.get(widget_id, DEFAULT_CONFIG["1"]))
    photos, _ = scan_images_for_widget(w_cfg)
    total = len(photos)

    if total == 0:
        return get_widget_state(widget_id)

    is_shuffle = w_cfg.get("shuffle", True)

    if is_shuffle and total > 1:
        # Pick a truly random photo, never picking the current one
        candidates = [p for p in photos if p != current_photo]
        chosen = random.choice(candidates) if candidates else random.choice(photos)
        return get_widget_state(widget_id, requested_photo=chosen)
    elif is_shuffle:
        return get_widget_state(widget_id, requested_photo=photos[0])
    else:
        # Sequential mode: advance by step
        cur_idx = 0
        if current_photo and current_photo in photos:
            cur_idx = photos.index(current_photo)
        else:
            cur_idx = w_cfg.get("current_index", 0) % total
        next_idx = (cur_idx + step) % total
        return get_widget_state(widget_id, requested_index=next_idx)

def pick_album(widget_id: str):
    cfg = load_config()
    w_cfg = cfg.get(widget_id, DEFAULT_CONFIG.get(widget_id, DEFAULT_CONFIG["1"]))
    folders = w_cfg.get("folders", [w_cfg.get("folder", str(HOME / "Pictures"))])
    start_dir = folders[0] if folders else str(HOME / "Pictures")

    cmd = [
        "zenity", "--file-selection", "--directory",
        f"--title=Select Photo Album (Widget {widget_id})",
        f"--filename={start_dir}/"
    ]
    env = get_wayland_env()
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, env=env)
        chosen = proc.stdout.strip()
        if chosen and Path(chosen).is_dir():
            return set_album_folder(widget_id, chosen)
    except Exception:
        pass

    return get_widget_state(widget_id)

def pick_files(widget_id: str):
    cfg = load_config()
    w_cfg = cfg.get(widget_id, DEFAULT_CONFIG.get(widget_id, DEFAULT_CONFIG["1"]))
    folders = w_cfg.get("folders", [w_cfg.get("folder", str(HOME / "Pictures"))])
    start_dir = folders[0] if folders else str(HOME / "Pictures")

    cmd = [
        "zenity", "--file-selection", "--multiple", "--separator=|",
        f"--title=Select Photos for Widget {widget_id}",
        f"--filename={start_dir}/"
    ]
    env = get_wayland_env()
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, text=True, check=True, env=env)
        chosen_str = proc.stdout.strip()
        if chosen_str:
            chosen_files = [str(Path(p).resolve()) for p in chosen_str.split("|") if Path(p).is_file() and Path(p).suffix in IMAGE_EXTS]
            if chosen_files:
                def _update(w):
                    w["mode"] = "files"
                    w["files"] = chosen_files
                    w["current_index"] = 0
                atomic_update_config(widget_id, _update)
    except Exception:
        pass

    return get_widget_state(widget_id)

def set_album_folder(widget_id: str, folder_path: str):
    p = Path(folder_path).resolve()
    if p.is_dir():
        fld_str = str(p)
        def _update(w):
            w["mode"] = "folders"
            w["folders"] = [fld_str]
            w["folder"] = fld_str
            w["files"] = []
            w["current_index"] = 0
        atomic_update_config(widget_id, _update)
    return get_widget_state(widget_id)

def set_multiple_albums(widget_id: str, folder_paths: list):
    valid = [str(Path(p).resolve()) for p in folder_paths if Path(p).is_dir()]
    if valid:
        def _update(w):
            w["mode"] = "folders"
            w["folders"] = valid
            w["folder"] = valid[0]
            w["files"] = []
            w["current_index"] = 0
        atomic_update_config(widget_id, _update)
    return get_widget_state(widget_id)

def toggle_album_folder(widget_id: str, folder_path: str):
    p = Path(folder_path).resolve()
    fld_str = str(p)
    pics_str = str(HOME / "Pictures")

    def _update(w):
        folders = [str(Path(f).resolve()) for f in w.get("folders", [])]
        if fld_str != pics_str and len(folders) == 1 and folders[0] == pics_str:
            # Switching from default Pictures (All Photos) to a specific album
            folders = [fld_str]
        elif fld_str in folders:
            if len(folders) > 1:
                folders.remove(fld_str)
            else:
                folders = [pics_str]
        else:
            if p.is_dir():
                folders.append(fld_str)

        w["mode"] = "folders"
        w["folders"] = folders
        w["folder"] = folders[0] if folders else pics_str
        w["files"] = []
        w["current_index"] = 0
    atomic_update_config(widget_id, _update)
    return get_widget_state(widget_id)

def open_in_dolphin(widget_id: str):
    st = get_widget_state(widget_id)
    cur_photo = st.get("current_photo")
    folder = st.get("folder")
    env = get_wayland_env()

    if cur_photo and Path(cur_photo).is_file():
        cmd = ["dolphin", "--select", cur_photo]
    elif folder and Path(folder).is_dir():
        cmd = ["dolphin", folder]
    else:
        cmd = ["dolphin", str(HOME / "Pictures")]

    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, env=env)
    return {"status": "ok", "opened": cmd}

def check_grid_collision(grid, key, col, row, col_span, row_span):
    if col < 0 or row < 0 or col + col_span > 6 or row + row_span > 4:
        return True
    for k, v in grid.items():
        if k == key:
            continue
        oc = v.get("col", 0)
        or_ = v.get("row", 0)
        ow = v.get("colSpan", 1)
        oh = v.get("rowSpan", 1)
        no_overlap = (col + col_span <= oc) or (oc + ow <= col) or (row + row_span <= or_) or (or_ + oh <= row)
        if not no_overlap:
            return True
    return False

def get_f1_data():
    cache_file = DATA_DIR / "f1_live_cache.json"
    cached_data = None
    if cache_file.exists():
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                cached_data = json.load(f)
                is_live_cached = cached_data.get("payload", {}).get("nextRace", {}).get("isRaceLive", False)
                cache_ttl = 30 if is_live_cached else 300
                if cached_data.get("_timestamp") and (datetime.now().timestamp() - cached_data["_timestamp"] < cache_ttl):
                    return cached_data["payload"]
        except Exception:
            pass

    try:
        import urllib.request
        from datetime import timezone

        CIRCUIT_SPECS = {
            "albert_park":   ("5.278 km", 58),
            "shanghai":      ("5.451 km", 56),
            "suzuka":        ("5.807 km", 53),
            "miami":         ("5.412 km", 57),
            "villeneuve":    ("4.361 km", 70),
            "monaco":        ("3.337 km", 78),
            "catalunya":     ("4.657 km", 66),
            "red_bull_ring": ("4.318 km", 71),
            "silverstone":   ("5.891 km", 52),
            "spa":           ("7.004 km", 44),
            "hungaroring":   ("4.381 km", 70),
            "zandvoort":     ("4.259 km", 72),
            "monza":         ("5.793 km", 53),
            "madring":       ("5.474 km", 57),
            "baku":          ("6.003 km", 51),
            "sepang":        ("5.543 km", 56),
            "marina_bay":    ("4.940 km", 62),
            "americas":      ("5.513 km", 56),
            "rodriguez":     ("4.304 km", 71),
            "interlagos":    ("4.309 km", 71),
            "vegas":         ("6.201 km", 50),
            "losail":        ("5.419 km", 57),
            "yas_marina":    ("5.281 km", 58),
            "bahrain":       ("5.412 km", 57),
            "jeddah":        ("6.174 km", 50),
            "imola":         ("4.909 km", 63),
        }

        CONSTRUCTOR_META = {
            "mercedes":     {"team": "Mercedes-AMG Petronas", "short": "Mercedes",     "teamKey": "mercedes",    "color": "#27F4D2"},
            "ferrari":      {"team": "Scuderia Ferrari",      "short": "Ferrari",      "teamKey": "ferrari",     "color": "#E80020"},
            "red_bull":     {"team": "Red Bull Racing",       "short": "Red Bull",     "teamKey": "redbull",     "color": "#3671C6"},
            "mclaren":      {"team": "McLaren F1 Team",       "short": "McLaren",      "teamKey": "mclaren",     "color": "#FF8000"},
            "rb":           {"team": "Racing Bulls",          "short": "Racing Bulls", "teamKey": "rb",          "color": "#6692FF"},
            "alpine":       {"team": "Alpine F1 Team",        "short": "Alpine",       "teamKey": "alpine",      "color": "#0093CC"},
            "haas":         {"team": "Haas F1 Team",          "short": "Haas",         "teamKey": "haas",        "color": "#E6002B"},
            "audi":         {"team": "Audi F1 Team",          "short": "Audi",         "teamKey": "audi",        "color": "#F50537"},
            "sauber":       {"team": "Audi F1 Team",          "short": "Audi",         "teamKey": "audi",        "color": "#F50537"},
            "williams":     {"team": "Williams Racing",       "short": "Williams",     "teamKey": "williams",    "color": "#00A0DE"},
            "aston_martin": {"team": "Aston Martin Aramco",   "short": "Aston Martin", "teamKey": "astonmartin", "color": "#229971"},
            "cadillac":     {"team": "Cadillac Formula 1",    "short": "Cadillac",     "teamKey": "cadillac",    "color": "#C5A059"},
        }

        F1_DRIVERS_2026 = {
            "antonelli": {"number": 12, "code": "ANT", "cid": "mercedes"},
            "russell":   {"number": 63, "code": "RUS", "cid": "mercedes"},
            "hamilton":  {"number": 44, "code": "HAM", "cid": "ferrari"},
            "leclerc":   {"number": 16, "code": "LEC", "cid": "ferrari"},
            "verstappen":{"number": 1,  "code": "VER", "cid": "red_bull"},
            "hadjar":    {"number": 6,  "code": "HAD", "cid": "red_bull"},
            "norris":    {"number": 4,  "code": "NOR", "cid": "mclaren"},
            "piastri":   {"number": 81, "code": "PIA", "cid": "mclaren"},
            "lawson":    {"number": 30, "code": "LAW", "cid": "rb"},
            "lindblad":  {"number": 41, "code": "LIN", "cid": "rb"},
            "tsunoda":   {"number": 22, "code": "TSU", "cid": "rb"},
            "alonso":    {"number": 14, "code": "ALO", "cid": "aston_martin"},
            "stroll":    {"number": 18, "code": "STR", "cid": "aston_martin"},
            "gasly":     {"number": 10, "code": "GAS", "cid": "alpine"},
            "colapinto": {"number": 43, "code": "COL", "cid": "alpine"},
            "albon":     {"number": 23, "code": "ALB", "cid": "williams"},
            "sainz":     {"number": 55, "code": "SAI", "cid": "williams"},
            "ocon":      {"number": 31, "code": "OCO", "cid": "haas"},
            "bearman":   {"number": 87, "code": "BEA", "cid": "haas"},
            "hülkenberg":{"number": 27, "code": "HUL", "cid": "audi"},
            "hulkenberg":{"number": 27, "code": "HUL", "cid": "audi"},
            "bortoleto": {"number": 5,  "code": "BOR", "cid": "audi"},
            "bottas":    {"number": 77, "code": "BOT", "cid": "cadillac"},
            "perez":     {"number": 11, "code": "PER", "cid": "cadillac"},
            "pérez":     {"number": 11, "code": "PER", "cid": "cadillac"},
            "herta":     {"number": 26, "code": "HER", "cid": "cadillac"},
        }

        # 1. Fetch Official Live Standings from Jolpica / Ergast API (Fast & Reliable)
        standings = []
        team_drivers_map = {}
        try:
            req_st = urllib.request.Request(
                "https://api.jolpi.ca/ergast/f1/current/driverStandings.json",
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req_st, timeout=4) as r:
                st_data = json.loads(r.read().decode())
            st_list = st_data.get("MRData", {}).get("StandingsTable", {}).get("StandingsLists", [{}])[0].get("DriverStandings", [])
            for item in st_list:
                drv = item.get("Driver", {})
                ctor = item.get("Constructors", [{}])[0]
                cid = ctor.get("constructorId", "")
                fname = drv.get("familyName", "")
                gname = drv.get("givenName", "")
                full_name = f"{gname} {fname}".strip()
                dmeta = F1_DRIVERS_2026.get(fname.lower())
                if not dmeta:
                    for k, v in F1_DRIVERS_2026.items():
                        if k in full_name.lower():
                            dmeta = v
                            break
                eff_cid = cid or (dmeta["cid"] if dmeta else "")
                cmeta = CONSTRUCTOR_META.get(eff_cid, {
                    "team": ctor.get("name", "Formula 1 Team"),
                    "short": ctor.get("name", "Formula 1 Team"),
                    "teamKey": "f1",
                    "color": "#E10600"
                })
                num_val = int(drv.get("permanentNumber") or (dmeta["number"] if dmeta else 0) or 0)
                code_val = drv.get("code") or (dmeta["code"] if dmeta else fname[:3].upper())
                if eff_cid:
                    team_drivers_map.setdefault(eff_cid, [])
                    if fname and fname not in team_drivers_map[eff_cid]:
                        team_drivers_map[eff_cid].append(fname)
                standings.append({
                    "pos": int(item.get("position") or (len(standings) + 1)),
                    "number": num_val,
                    "driver": f"{gname[:1]}. {fname}" if gname else fname,
                    "fullName": full_name,
                    "code": code_val,
                    "team": cmeta["team"],
                    "teamKey": cmeta["teamKey"],
                    "pts": int(float(item.get("points") or 0)),
                    "color": cmeta["color"]
                })
        except Exception:
            pass

        # 1b. Fetch Official Live Constructor Standings from Jolpica / Ergast API
        constructor_standings = []
        try:
            req_cs = urllib.request.Request(
                "https://api.jolpi.ca/ergast/f1/current/constructorStandings.json",
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req_cs, timeout=4) as rcs:
                cs_data = json.loads(rcs.read().decode())
            cs_list = cs_data.get("MRData", {}).get("StandingsTable", {}).get("StandingsLists", [{}])[0].get("ConstructorStandings", [])
            for item in cs_list:
                ctor = item.get("Constructor", {})
                cid = ctor.get("constructorId", "")
                cmeta = CONSTRUCTOR_META.get(cid, {
                    "team": ctor.get("name", "Formula 1 Team"),
                    "short": ctor.get("name", "Formula 1 Team"),
                    "teamKey": "f1",
                    "color": "#E10600"
                })
                drvs = team_drivers_map.get(cid, [])[:2]
                constructor_standings.append({
                    "pos": int(item.get("position") or (len(constructor_standings) + 1)),
                    "team": cmeta["team"],
                    "shortName": cmeta["short"],
                    "teamKey": cmeta["teamKey"],
                    "pts": int(float(item.get("points") or 0)),
                    "wins": int(item.get("wins") or 0),
                    "nationality": ctor.get("nationality", ""),
                    "drivers": " • ".join(drvs) if drvs else ctor.get("nationality", ""),
                    "color": cmeta["color"]
                })
        except Exception:
            pass

        # Fallback to ESPN if standings empty
        if not standings:
            try:
                req_st = urllib.request.Request(
                    "https://site.web.api.espn.com/apis/v2/sports/racing/f1/standings",
                    headers={"User-Agent": "Mozilla/5.0"}
                )
                with urllib.request.urlopen(req_st, timeout=4) as r:
                    st_data = json.loads(r.read().decode())
                driver_group = next((g for g in st_data.get("children", []) if "driver" in g.get("name", "").lower()), None)
                if driver_group:
                    entries = driver_group.get("standings", {}).get("entries", [])
                    for e in entries:
                        ath = e.get("athlete", {})
                        stats = {s.get("name"): s.get("displayValue") for s in e.get("stats", [])}
                        full_name = ath.get("displayName", "")
                        dmeta = None
                        for k, v in F1_DRIVERS_2026.items():
                            if k in full_name.lower():
                                dmeta = v
                                break
                        cmeta = CONSTRUCTOR_META.get(dmeta["cid"], {}) if dmeta else {}
                        try:
                            pts_val = int(stats.get("championshipPts") or stats.get("points") or 0)
                        except:
                            pts_val = 0
                        standings.append({
                            "pos": int(stats.get("rank") or (len(standings) + 1)),
                            "number": dmeta["number"] if dmeta else 0,
                            "driver": ath.get("shortName") or full_name,
                            "fullName": full_name,
                            "code": dmeta["code"] if dmeta else (ath.get("shortName") or full_name)[:3].upper(),
                            "team": cmeta.get("team", "Formula 1 Team"),
                            "teamKey": cmeta.get("teamKey", "f1"),
                            "pts": pts_val,
                            "color": cmeta.get("color", "#E10600")
                        })
            except Exception:
                pass

        # 2. Fetch Official Live Race Schedule and Sessions from Jolpica / Ergast
        now_utc = datetime.now(timezone.utc)
        clean_name = "Mexico City Grand Prix"
        short_name = "Mexico City GP"
        circuit_id = "vegas"
        circuit_full = "Autodromo Hermanos Rodriguez"
        location_str = "Mexico City, Mexico"
        round_no = 20
        total_rounds = 24
        session_label = "RACE"
        session_full = "Grand Prix Race"
        session_date = "Sunday, Nov 01"
        session_time = "20:00 UTC"
        session_seconds = 200000
        session_countdown = "02d 10h 30m"

        try:
            req_jp = urllib.request.Request(
                "https://api.jolpi.ca/ergast/f1/current/next.json",
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req_jp, timeout=4) as rjp:
                jp_data = json.loads(rjp.read().decode())
            r_info = jp_data.get("MRData", {}).get("RaceTable", {}).get("Races", [{}])[0]
            if r_info:
                clean_name = r_info.get("raceName", clean_name)
                short_name = clean_name.replace("Grand Prix", "GP").strip()
                c_obj = r_info.get("Circuit", {})
                circuit_id = c_obj.get("circuitId", circuit_id)
                circuit_full = c_obj.get("circuitName", circuit_full)
                loc_obj = c_obj.get("Location", {})
                city = loc_obj.get("locality", "Mexico City")
                country = loc_obj.get("country", "Mexico")
                location_str = f"{city}, {country}"
                round_no = int(r_info.get("round", 20))

                sess_candidates = [
                    ("FirstPractice", "FP1", "Practice 1"),
                    ("SecondPractice", "FP2", "Practice 2"),
                    ("ThirdPractice", "FP3", "Practice 3"),
                    ("SprintQualifying", "SPRINT QUALI", "Sprint Qualifying"),
                    ("Sprint", "SPRINT", "Sprint Race"),
                    ("Qualifying", "QUALI", "Qualifying"),
                ]
                parsed_sessions = []
                for skey, slbl, sfull in sess_candidates:
                    sobj = r_info.get(skey)
                    if sobj and "date" in sobj and "time" in sobj:
                        try:
                            sdt = datetime.fromisoformat(f"{sobj['date']}T{sobj['time'].replace('Z', '+00:00')}")
                            parsed_sessions.append((skey, slbl, sfull, sdt))
                        except Exception:
                            pass
                if "date" in r_info and "time" in r_info:
                    try:
                        rdt = datetime.fromisoformat(f"{r_info['date']}T{r_info['time'].replace('Z', '+00:00')}")
                        parsed_sessions.append(("Race", "RACE", "Grand Prix Race", rdt))
                    except Exception:
                        pass

                parsed_sessions.sort(key=lambda x: x[3])
                for skey, slbl, sfull, sdt in parsed_sessions:
                    s_sec = (sdt - now_utc).total_seconds()
                    # Upcoming or started less than 90m ago
                    if s_sec > -5400:
                        session_label = slbl
                        session_full = sfull
                        session_date = sdt.strftime("%A, %b %d")
                        session_time = sdt.strftime("%H:%M UTC")
                        session_seconds = max(0, int(s_sec))
                        sdays = session_seconds // 86400
                        shours = (session_seconds % 86400) // 3600
                        smins = (session_seconds % 3600) // 60
                        ssecs = session_seconds % 60
                        if s_sec <= 0:
                            session_countdown = "LIVE NOW"
                        elif sdays > 0:
                            session_countdown = f"{sdays:02d}d {shours:02d}h {smins:02d}m"
                        else:
                            session_countdown = f"{shours:02d}h {smins:02d}m {ssecs:02d}s"
                        break
        except Exception:
            pass

        track_points = []
        try:
            tracks_path = Path(__file__).resolve().parent / "f1_tracks.json"
            if tracks_path.exists():
                with open(tracks_path, "r", encoding="utf-8") as tf:
                    track_points = json.load(tf).get(circuit_id, [])
        except Exception:
            pass

        # 3. Current GP Qualifying & Live Race Positions / Lap Count
        c_length, total_laps = CIRCUIT_SPECS.get(circuit_id, ("5.4 km", 55))
        current_lap = 0
        is_race_live = False

        # Build fast name -> live driver metadata lookup from current standings + static fallback
        drv_lookup = {}
        for s_item in standings:
            fn = s_item["fullName"].lower()
            ln = fn.split()[-1] if fn else ""
            drv_lookup[fn] = s_item
            if ln:
                drv_lookup[ln] = s_item

        def resolve_driver_meta(full_name, cid_hint=""):
            low = (full_name or "").lower().strip()
            ln = low.split()[-1] if low else ""
            if cid_hint and cid_hint in CONSTRUCTOR_META:
                cm = CONSTRUCTOR_META[cid_hint]
                dm = F1_DRIVERS_2026.get(ln)
                return {
                    "number": dm["number"] if dm else 0,
                    "code": dm["code"] if dm else (ln[:3].upper() or "DRV"),
                    "team": cm["team"],
                    "teamKey": cm["teamKey"],
                    "color": cm["color"],
                }
            if low in drv_lookup:
                return drv_lookup[low]
            if ln in drv_lookup:
                return drv_lookup[ln]
            for k, v in drv_lookup.items():
                if k and k in low:
                    return v
            dm = F1_DRIVERS_2026.get(ln)
            if dm:
                cm = CONSTRUCTOR_META.get(dm["cid"], {})
                return {
                    "number": dm["number"],
                    "code": dm["code"],
                    "team": cm.get("team", "Formula 1 Team"),
                    "teamKey": cm.get("teamKey", "f1"),
                    "color": cm.get("color", "#E10600"),
                }
            return {
                "number": 0,
                "code": (ln[:3].upper() if ln else "DRV"),
                "team": "Formula 1 Team",
                "teamKey": "f1",
                "color": "#E10600",
            }

        qualifying = []
        try:
            req_q = urllib.request.Request(
                f"https://api.jolpi.ca/ergast/f1/current/{round_no}/qualifying.json",
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req_q, timeout=4) as rq:
                q_data = json.loads(rq.read().decode())
            q_races = q_data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
            if q_races:
                for qr in q_races[0].get("QualifyingResults", []):
                    drv = qr.get("Driver", {})
                    ctor = qr.get("Constructor", {})
                    full_name = f"{drv.get('givenName', '')} {drv.get('familyName', '')}".strip()
                    meta = resolve_driver_meta(full_name, ctor.get("constructorId", ""))
                    if qr.get("Q3"):
                        q_time, q_seg = qr["Q3"], "Q3"
                    elif qr.get("Q2"):
                        q_time, q_seg = qr["Q2"], "Q2"
                    else:
                        q_time, q_seg = (qr.get("Q1") or "NO TIME"), "Q1"
                    qualifying.append({
                        "pos": int(qr.get("position") or (len(qualifying) + 1)),
                        "number": int(drv.get("permanentNumber") or meta["number"] or 0),
                        "code": drv.get("code") or meta["code"],
                        "fullName": full_name,
                        "team": meta["team"],
                        "teamKey": meta["teamKey"],
                        "color": meta["color"],
                        "metric": q_time,
                        "unit": q_seg,
                    })
        except Exception:
            pass

        race_standings = []
        try:
            req_espn = urllib.request.Request(
                "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard",
                headers={"User-Agent": "Mozilla/5.0"}
            )
            with urllib.request.urlopen(req_espn, timeout=4) as re_sb:
                sb = json.loads(re_sb.read().decode())
            evs = sb.get("events", [])
            if evs:
                ev_obj = evs[0]
                ev_id = str(ev_obj.get("id") or "")
                comps = ev_obj.get("competitions", [])
                race_comp = next((c for c in comps if c.get("type", {}).get("abbreviation") == "Race"), None)
                qual_comp = next((c for c in comps if c.get("type", {}).get("abbreviation") == "Qual"), None)

                if race_comp:
                    race_cid = str(race_comp.get("id") or "")
                    race_start_ts = 0.0
                    if race_comp.get("date"):
                        try:
                            sdt_r = datetime.fromisoformat(race_comp["date"].replace("Z", "+00:00"))
                            race_start_ts = sdt_r.timestamp()
                        except Exception:
                            pass

                    r_stat = race_comp.get("status", {})
                    r_state = r_stat.get("type", {}).get("state", "pre")
                    period = int(r_stat.get("period") or 0)
                    if r_state == "in":
                        is_race_live = True
                        current_lap = period
                        session_label = "RACE"
                        session_countdown = f"LAP {current_lap}/{total_laps}" if current_lap > 0 else "LIVE"
                        session_seconds = 0
                    elif r_state == "post" and session_countdown == "LIVE NOW":
                        session_countdown = "FINAL"

                    competitors = sorted(race_comp.get("competitors", []), key=lambda x: int(x.get("order") or 99))

                    # Fetch live millisecond gaps & laps completed in parallel
                    comp_stats_map = {}
                    if ev_id and race_cid and r_state in ("in", "post"):
                        from concurrent.futures import ThreadPoolExecutor

                        def _fetch_comp_stat(comp_id):
                            if not comp_id:
                                return comp_id, {}
                            s_url = f"https://sports.core.api.espn.com/v2/sports/racing/leagues/f1/events/{ev_id}/competitions/{race_cid}/competitors/{comp_id}/statistics?lang=en&region=us"
                            try:
                                req_s = urllib.request.Request(s_url, headers={"User-Agent": "Mozilla/5.0"})
                                with urllib.request.urlopen(req_s, timeout=3) as rs:
                                    s_json = json.loads(rs.read().decode())
                                flat = {}
                                for cat in s_json.get("splits", {}).get("categories", []):
                                    for st in cat.get("stats", []):
                                        if st.get("name"):
                                            flat[st["name"]] = st
                                return comp_id, flat
                            except Exception:
                                return comp_id, {}

                        with ThreadPoolExecutor(max_workers=10) as pool:
                            for c_id, st_flat in pool.map(lambda c: _fetch_comp_stat(str(c.get("id") or "")), competitors):
                                comp_stats_map[c_id] = st_flat

                    p1_laps = 0
                    if competitors:
                        p1_st = comp_stats_map.get(str(competitors[0].get("id") or ""), {})
                        p1_laps = int(float(p1_st.get("lapsCompleted", {}).get("value", 0) or 0)) or current_lap

                    for c_item in competitors:
                        ath = c_item.get("athlete", {})
                        full_name = ath.get("displayName", "")
                        meta = resolve_driver_meta(full_name)
                        pos_num = int(c_item.get("order") or (len(race_standings) + 1))
                        c_id = str(c_item.get("id") or "")
                        c_st = comp_stats_map.get(c_id, {})

                        metric_str = "PRE"
                        if r_state == "in" or r_state == "post":
                            if pos_num == 1:
                                upd_ms = float(c_st.get("lastUpdated", {}).get("value", 0) or 0)
                                if upd_ms > 0 and race_start_ts > 0:
                                    el = max(0, int(upd_ms / 1000.0 - race_start_ts))
                                    eh = el // 3600
                                    em = (el % 3600) // 60
                                    es = el % 60
                                    metric_str = f"{eh}:{em:02d}:{es:02d}" if eh > 0 else f"{em}:{es:02d}"
                                else:
                                    metric_str = f"LAP {current_lap}" if current_lap > 0 else "LEADER"
                            else:
                                gap_obj = c_st.get("gapToLeader", {})
                                gap_disp = gap_obj.get("displayValue", "")
                                gap_ms = gap_obj.get("value")
                                laps_comp = int(float(c_st.get("lapsCompleted", {}).get("value", 0) or 0))
                                if gap_disp:
                                    try:
                                        if gap_ms is not None and float(gap_ms) >= 60000:
                                            sec_f = float(gap_ms) / 1000.0
                                            m_i = int(sec_f // 60)
                                            rem = sec_f - m_i * 60
                                            metric_str = f"+{m_i}:{rem:06.3f}"
                                        else:
                                            metric_str = gap_disp
                                    except Exception:
                                        metric_str = gap_disp
                                elif laps_comp > 0 and p1_laps > laps_comp:
                                    dl = p1_laps - laps_comp
                                    metric_str = f"+{dl} LAP" if dl == 1 else f"+{dl} LAPS"
                                elif r_state == "post":
                                    metric_str = "FIN"
                                else:
                                    metric_str = "GAP"

                        race_standings.append({
                            "pos": pos_num,
                            "number": meta["number"],
                            "code": meta["code"],
                            "fullName": full_name,
                            "team": meta["team"],
                            "teamKey": meta["teamKey"],
                            "color": meta["color"],
                            "metric": metric_str,
                            "unit": "",
                        })

                if not qualifying and qual_comp:
                    q_comps = sorted(qual_comp.get("competitors", []), key=lambda x: int(x.get("order") or 99))
                    for c_item in q_comps:
                        ath = c_item.get("athlete", {})
                        full_name = ath.get("displayName", "")
                        meta = resolve_driver_meta(full_name)
                        qualifying.append({
                            "pos": int(c_item.get("order") or (len(qualifying) + 1)),
                            "number": meta["number"],
                            "code": meta["code"],
                            "fullName": full_name,
                            "team": meta["team"],
                            "teamKey": meta["teamKey"],
                            "color": meta["color"],
                            "metric": "P" + str(c_item.get("order") or (len(qualifying) + 1)),
                            "unit": "GRID",
                        })
        except Exception:
            pass

        payload = {
            "status": "ok",
            "sport": "f1",
            "source": "jolpica_f1_api",
            "nextRace": {
                "name": clean_name,
                "shortName": short_name,
                "circuitId": circuit_id,
                "trackPoints": track_points,
                "circuit": circuit_full,
                "location": location_str,
                "date": session_date,
                "time": session_time,
                "sessionLabel": session_label,
                "sessionFullLabel": session_full,
                "sessionDate": session_date,
                "sessionTime": session_time,
                "round": f"Round {round_no} / {total_rounds}",
                "laps": total_laps,
                "currentLap": current_lap,
                "isRaceLive": is_race_live,
                "circuitLength": c_length,
                "countdown": session_countdown,
                "secondsRemaining": session_seconds,
                "compounds": [
                    {"code": "C3", "compound": "Hard", "color": "#FFFFFF", "textColor": "#000000"},
                    {"code": "C4", "compound": "Medium", "color": "#FFD700", "textColor": "#000000"},
                    {"code": "C5", "compound": "Soft", "color": "#E10600", "textColor": "#FFFFFF"}
                ]
            },
            "standings": standings,
            "constructorStandings": constructor_standings,
            "raceStandings": race_standings,
            "qualifying": qualifying
        }
        try:
            with open(cache_file, "w", encoding="utf-8") as f:
                json.dump({"_timestamp": datetime.now().timestamp(), "payload": payload}, f)
        except Exception:
            pass
        return payload

    except Exception:
        pass

    if cached_data and cached_data.get("payload"):
        return cached_data["payload"]

    return {
        "status": "ok",
        "sport": "f1",
        "source": "fallback",
        "nextRace": {
            "name": "Mexico City Grand Prix",
            "shortName": "Mexico City GP",
            "circuit": "Autodromo Hermanos Rodriguez",
            "location": "Mexico City, Mexico",
            "date": "Friday, Oct 30",
            "time": "18:30 UTC",
            "round": "Round 21 / 25",
            "laps": 71,
            "circuitLength": "4.304 km",
            "countdown": "03d 18h 00m",
            "secondsRemaining": 324000,
            "compounds": [
                {"code": "C3", "compound": "Hard", "color": "#FFFFFF", "textColor": "#000000"},
                {"code": "C4", "compound": "Medium", "color": "#FFD700", "textColor": "#000000"},
                {"code": "C5", "compound": "Soft", "color": "#E10600", "textColor": "#FFFFFF"}
            ]
        },
        "standings": [],
        "constructorStandings": []
    }

def get_f1_calendar():
    cache_file = DATA_DIR / "f1_calendar_cache.json"
    cache_ttl = 3600 * 12  # 12 hours
    if cache_file.exists():
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                cached = json.load(f)
                if cached.get("_timestamp") and (datetime.now().timestamp() - cached["_timestamp"] < cache_ttl):
                    return cached["payload"]
        except Exception:
            pass

    import urllib.request
    from datetime import datetime

    events = {}
    try:
        req = urllib.request.Request("https://api.jolpi.ca/ergast/f1/current.json", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
        races = data.get("MRData", {}).get("RaceTable", {}).get("Races", [])
        total_rounds = len(races)
        for r in races:
            r_name = r.get("raceName", "Grand Prix")
            round_no = r.get("round", "1")
            round_str = f"Round {round_no} / {total_rounds}"
            circuit = r.get("Circuit", {}).get("circuitName", "Formula 1 Circuit")
            loc = r.get("Circuit", {}).get("Location", {})
            city = loc.get("locality", "")
            country = loc.get("country", "")
            location_str = f"{city}, {country}".strip(", ")

            sessions = [
                ("FirstPractice", "Practice 1 (FP1)", "FP1"),
                ("SecondPractice", "Practice 2 (FP2)", "FP2"),
                ("ThirdPractice", "Practice 3 (FP3)", "FP3"),
                ("SprintQualifying", "Sprint Qualifying", "Sprint Qualy"),
                ("Sprint", "Sprint Race", "Sprint"),
                ("Qualifying", "Qualifying", "Qualy"),
            ]
            for skey, sfull, sshort in sessions:
                sobj = r.get(skey)
                if sobj and "date" in sobj:
                    d = sobj["date"]
                    t = sobj.get("time", "")
                    events[d] = {
                        "raceName": r_name,
                        "session": sfull,
                        "sessionShort": sshort,
                        "round": round_str,
                        "circuit": circuit,
                        "location": location_str,
                        "time": t,
                        "isRace": False
                    }

            if "date" in r:
                d = r["date"]
                t = r.get("time", "")
                events[d] = {
                    "raceName": r_name,
                    "session": "Gran Premio (Carrera)",
                    "sessionShort": "Race",
                    "round": round_str,
                    "circuit": circuit,
                    "location": location_str,
                    "time": t,
                    "isRace": True
                }
    except Exception:
        pass

    # Ensure Mexico City GP fallback or current nextRace if missing
    if "2026-11-01" not in events:
        events["2026-11-01"] = {
            "raceName": "Mexico City Grand Prix",
            "session": "Gran Premio (Carrera)",
            "sessionShort": "Race",
            "round": "Round 19 / 24",
            "circuit": "Autódromo Hermanos Rodríguez",
            "location": "Mexico City, Mexico",
            "time": "20:00:00Z",
            "isRace": True
        }

    try:
        with open(cache_file, "w", encoding="utf-8") as f:
            json.dump({"_timestamp": datetime.now().timestamp(), "payload": events}, f, ensure_ascii=False)
    except Exception:
        pass

    return events

def get_nba_data():
    cache_file = DATA_DIR / "nba_cache.json"
    cache_ttl = 60
    cached_data = None
    if cache_file.exists():
        try:
            with open(cache_file, "r", encoding="utf-8") as f:
                cached_data = json.load(f)
                if cached_data.get("_timestamp") and (datetime.now().timestamp() - cached_data["_timestamp"] < cache_ttl):
                    return cached_data["payload"]
        except Exception:
            pass

    try:
        import urllib.request
        # 1. Fetch live scoreboard games from ESPN API
        req_sb = urllib.request.Request(
            "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard",
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req_sb, timeout=5) as res:
            raw = json.loads(res.read().decode())
            games = []
            events = raw.get("events", [])
            for ev in events:
                comp = ev.get("competitions", [{}])[0]
                status_obj = comp.get("status", {})
                detail = status_obj.get("type", {}).get("shortDetail", "Scheduled")
                state = status_obj.get("type", {}).get("state", "pre")
                competitors = comp.get("competitors", [])
                if len(competitors) >= 2:
                    home = next((c for c in competitors if c.get("homeAway") == "home"), competitors[0])
                    away = next((c for c in competitors if c.get("homeAway") == "away"), competitors[1])
                    games.append({
                        "id": ev.get("id"),
                        "name": ev.get("name"),
                        "status": detail,
                        "state": state,
                        "home": {
                            "team": home.get("team", {}).get("abbreviation", "HOM"),
                            "name": home.get("team", {}).get("shortDisplayName", "Home"),
                            "score": str(home.get("score", "0")),
                            "color": "#" + home.get("team", {}).get("color", "1D428A"),
                            "record": home.get("records", [{}])[0].get("summary", "") if home.get("records") else ""
                        },
                        "away": {
                            "team": away.get("team", {}).get("abbreviation", "AWY"),
                            "name": away.get("team", {}).get("shortDisplayName", "Away"),
                            "score": str(away.get("score", "0")),
                            "color": "#" + away.get("team", {}).get("color", "C9082A"),
                            "record": away.get("records", [{}])[0].get("summary", "") if away.get("records") else ""
                        }
                    })

        # 2. Fetch live standings / conference leaders from ESPN API
        req_st = urllib.request.Request(
            "https://site.web.api.espn.com/apis/v2/sports/basketball/nba/standings",
            headers={"User-Agent": "Mozilla/5.0"}
        )
        east_top = {"team": "DET", "name": "Pistons", "record": "3-0"}
        west_top = {"team": "MIN", "name": "Timberwolves", "record": "3-0"}
        try:
            with urllib.request.urlopen(req_st, timeout=5) as r:
                st_data = json.loads(r.read().decode())
                for conf in st_data.get("children", []):
                    cname = conf.get("name", "").lower()
                    entries = conf.get("standings", {}).get("entries", [])
                    def get_seed(e):
                        for s in e.get("stats", []):
                            if s.get("name") == "playoffSeed":
                                try: return int(s.get("value", 99))
                                except: pass
                        return 99
                    sorted_entries = sorted(entries, key=get_seed)
                    if sorted_entries:
                        top = sorted_entries[0]
                        t = top.get("team", {})
                        stats = {s.get("name"): s.get("displayValue") for s in top.get("stats", [])}
                        info = {
                            "team": t.get("abbreviation", "TOP"),
                            "name": t.get("shortDisplayName", t.get("displayName", "Leader")),
                            "record": stats.get("overall", stats.get("record", "")) or (stats.get("wins", "") + "-" + stats.get("losses", ""))
                        }
                        if "east" in cname:
                            east_top = info
                        elif "west" in cname:
                            west_top = info
        except Exception:
            pass

        if games:
            payload = {
                "status": "ok",
                "sport": "nba",
                "source": "espn_live_api",
                "games": games,
                "standings": {
                    "east": [east_top],
                    "west": [west_top]
                }
            }
            try:
                with open(cache_file, "w", encoding="utf-8") as f:
                    json.dump({"_timestamp": datetime.now().timestamp(), "payload": payload}, f)
            except Exception:
                pass
            return payload

    except Exception:
        pass

    if cached_data and cached_data.get("payload"):
        return cached_data["payload"]

    return {
        "status": "ok",
        "sport": "nba",
        "source": "fallback",
        "games": [],
        "standings": {
            "east": [{"team": "DET", "name": "Pistons", "record": "3-0"}],
            "west": [{"team": "MIN", "name": "Timberwolves", "record": "3-0"}]
        }
    }

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "photos-get":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        cur = sys.argv[3] if len(sys.argv) > 3 else ""
        res = get_widget_state(wid, requested_photo=cur or None)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-next":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        cur = sys.argv[3] if len(sys.argv) > 3 else ""
        res = cycle_widget(wid, 1, current_photo=cur)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-prev":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        cur = sys.argv[3] if len(sys.argv) > 3 else ""
        res = cycle_widget(wid, -1, current_photo=cur)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-pick-album":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        res = pick_album(wid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-pick-files":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        res = pick_files(wid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-set-folder":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        fld = sys.argv[3] if len(sys.argv) > 3 else str(HOME / "Pictures")
        res = set_album_folder(wid, fld)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-set-albums":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        flds = sys.argv[3:]
        res = set_multiple_albums(wid, flds)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-toggle-album":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        fld = sys.argv[3] if len(sys.argv) > 3 else str(HOME / "Pictures")
        res = toggle_album_folder(wid, fld)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-open-dolphin":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        res = open_in_dolphin(wid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-toggle-recursive":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        cur = sys.argv[3] if len(sys.argv) > 3 else ""
        def _u(w):
            w["recursive"] = not w.get("recursive", True)
            w["current_index"] = 0
        atomic_update_config(wid, _u)
        res = get_widget_state(wid, requested_photo=cur or None)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-toggle-shuffle":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        cur = sys.argv[3] if len(sys.argv) > 3 else ""
        def _u(w):
            w["shuffle"] = not w.get("shuffle", True)
            w["current_index"] = 0
        atomic_update_config(wid, _u)
        res = get_widget_state(wid, requested_photo=cur or None)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-set-fit":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        fmode = sys.argv[3] if len(sys.argv) > 3 else "crop"
        cur = sys.argv[4] if len(sys.argv) > 4 else ""
        def _u(w):
            w["fit_mode"] = fmode
        atomic_update_config(wid, _u)
        res = get_widget_state(wid, requested_photo=cur or None)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-set-interval":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        try:
            sec = int(sys.argv[3]) if len(sys.argv) > 3 else 30
        except ValueError:
            sec = 30
        cur = sys.argv[4] if len(sys.argv) > 4 else ""
        def _u(w):
            w["interval"] = sec
        atomic_update_config(wid, _u)
        res = get_widget_state(wid, requested_photo=cur or None)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "albums-list":
        res = list_user_albums()
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "notes-get":
        notes = load_notes()
        print(json.dumps(notes, ensure_ascii=False))

    elif cmd == "notes-save":
        title = sys.argv[2] if len(sys.argv) > 2 else "Quick Notes"
        content = sys.argv[3] if len(sys.argv) > 3 else ""
        notes = {
            "title": title,
            "content": content,
            "updated_at": datetime.now().strftime("%d/%m/%Y %H:%M")
        }
        save_notes(notes)
        print(json.dumps(notes, ensure_ascii=False))

    elif cmd == "grid-get":
        grid = load_grid()
        print(json.dumps(grid, ensure_ascii=False))

    elif cmd == "grid-save":
        raw = sys.argv[2] if len(sys.argv) > 2 else "{}"
        try:
            parsed = json.loads(raw)
            save_grid(parsed)
            print(json.dumps({"status": "ok", "saved": parsed}, ensure_ascii=False))
        except Exception as e:
            print(json.dumps({"error": str(e)}))

    elif cmd == "grid-add":
        key = sys.argv[2]
        w_type = sys.argv[3] if len(sys.argv) > 3 else key
        col = int(sys.argv[4]) if len(sys.argv) > 4 else 0
        row = int(sys.argv[5]) if len(sys.argv) > 5 else 0
        cspan = int(sys.argv[6]) if len(sys.argv) > 6 else 1
        rspan = int(sys.argv[7]) if len(sys.argv) > 7 else 1
        grid = load_grid()
        grid[key] = {
            "col": col,
            "row": row,
            "colSpan": cspan,
            "rowSpan": rspan,
            "type": w_type
        }
        save_grid(grid)
        print(json.dumps({"status": "ok", "grid": grid}, ensure_ascii=False))

    elif cmd == "grid-remove":
        key = sys.argv[2]
        grid = load_grid()
        if key in grid:
            del grid[key]
            save_grid(grid)
        print(json.dumps({"status": "ok", "grid": grid}, ensure_ascii=False))

    elif cmd == "grid-move":
        key = sys.argv[2]
        col = int(sys.argv[3])
        row = int(sys.argv[4])
        grid = load_grid()
        if key in grid:
            cw = grid[key].get("colSpan", 1)
            rw = grid[key].get("rowSpan", 1)
            if not check_grid_collision(grid, key, col, row, cw, rw):
                grid[key]["col"] = col
                grid[key]["row"] = row
                save_grid(grid)
                print(json.dumps({"status": "ok", "grid": grid}, ensure_ascii=False))
            else:
                print(json.dumps({"status": "error", "message": f"Collision detected at ({col}, {row}). Move cancelled."}, ensure_ascii=False))

    elif cmd == "grid-resize":
        key = sys.argv[2]
        cspan = int(sys.argv[3])
        rspan = int(sys.argv[4])
        grid = load_grid()
        if key in grid:
            col = grid[key].get("col", 0)
            row = grid[key].get("row", 0)
            if not check_grid_collision(grid, key, col, row, cspan, rspan):
                grid[key]["colSpan"] = cspan
                grid[key]["rowSpan"] = rspan
                save_grid(grid)
                print(json.dumps({"status": "ok", "grid": grid}, ensure_ascii=False))
            else:
                print(json.dumps({"status": "error", "message": f"Resize collision detected. Expansion cancelled."}, ensure_ascii=False))

    elif cmd == "f1-data":
        print(json.dumps(get_f1_data(), ensure_ascii=False))

    elif cmd == "f1-calendar":
        print(json.dumps(get_f1_calendar(), ensure_ascii=False))

    elif cmd == "nba-data":
        print(json.dumps(get_nba_data(), ensure_ascii=False))

    elif cmd == "grid-reset":
        save_grid(DEFAULT_GRID)
        print(json.dumps({"status": "ok", "grid": DEFAULT_GRID}, ensure_ascii=False))

    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
