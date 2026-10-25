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
    "clock":     { "col": 0, "row": 0, "colSpan": 1, "rowSpan": 1, "type": "clock" },
    "battery":   { "col": 1, "row": 0, "colSpan": 1, "rowSpan": 1, "type": "battery" },
    "calendar":  { "col": 0, "row": 1, "colSpan": 1, "rowSpan": 1, "type": "calendar" },
    "weather":   { "col": 1, "row": 1, "colSpan": 1, "rowSpan": 1, "type": "weather" },
    "resources": { "col": 0, "row": 2, "colSpan": 1, "rowSpan": 1, "type": "resources" },
    "reminders": { "col": 1, "row": 2, "colSpan": 1, "rowSpan": 1, "type": "reminders" },
    "media":     { "col": 0, "row": 3, "colSpan": 2, "rowSpan": 1, "type": "media" },
    "photo1":    { "col": 2, "row": 0, "colSpan": 2, "rowSpan": 2, "type": "photo1" },
    "notes":     { "col": 4, "row": 0, "colSpan": 2, "rowSpan": 1, "type": "notes" }
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
            w_cfg = cfg.get(widget_id, DEFAULT_CONFIG.get(widget_id, DEFAULT_CONFIG["1"]).copy())
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

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "photos-get":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        res = get_widget_state(wid)
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
        def _u(w):
            w["recursive"] = not w.get("recursive", True)
            w["current_index"] = 0
        atomic_update_config(wid, _u)
        res = get_widget_state(wid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-toggle-shuffle":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        def _u(w):
            w["shuffle"] = not w.get("shuffle", True)
            w["current_index"] = 0
        atomic_update_config(wid, _u)
        res = get_widget_state(wid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-set-fit":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        fmode = sys.argv[3] if len(sys.argv) > 3 else "crop"
        def _u(w):
            w["fit_mode"] = fmode
        atomic_update_config(wid, _u)
        res = get_widget_state(wid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "photos-set-interval":
        wid = sys.argv[2] if len(sys.argv) > 2 else "1"
        try:
            sec = int(sys.argv[3]) if len(sys.argv) > 3 else 30
        except ValueError:
            sec = 30
        def _u(w):
            w["interval"] = sec
        atomic_update_config(wid, _u)
        res = get_widget_state(wid)
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

    elif cmd == "grid-reset":
        save_grid(DEFAULT_GRID)
        print(json.dumps({"status": "ok", "grid": DEFAULT_GRID}, ensure_ascii=False))

    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
