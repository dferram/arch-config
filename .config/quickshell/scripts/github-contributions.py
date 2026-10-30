#!/usr/bin/env python3
"""
github-contributions.py
Fetches and caches GitHub contribution calendar ("green wall") for the current year.
Designed for Quickshell Apple Sonoma Desktop Widgets.
"""

import sys
import os
import json
import time
import datetime
import urllib.request
import urllib.error
import re
from pathlib import Path

DATA_DIR = Path.home() / ".local" / "share" / "desktop-widgets"
DATA_DIR.mkdir(parents=True, exist_ok=True)
CACHE_TTL = 1800  # 30 minutes cache


def get_default_username():
    # Try git config
    try:
        import subprocess
        res = subprocess.run(["git", "config", "--get", "github.user"], capture_output=True, text=True)
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    return "dferram"


def fetch_user_profile(username):
    url = f"https://api.github.com/users/{username}"
    req = urllib.request.Request(url, headers={"User-Agent": "Quickshell-Widget/1.0"})
    avatar_local_path = ""
    name = username
    bio = ""
    public_repos = 0
    try:
        with urllib.request.urlopen(req, timeout=6) as resp:
            data = json.loads(resp.read().decode())
            name = data.get("name") or username
            bio = data.get("bio") or ""
            public_repos = data.get("public_repos", 0)
            avatar_url = data.get("avatar_url")
            if avatar_url:
                avatar_file = DATA_DIR / f"avatar_{username}.png"
                # Download if not exists or older than 7 days
                if not avatar_file.exists() or (time.time() - avatar_file.stat().st_mtime > 7 * 86400):
                    try:
                        img_req = urllib.request.Request(avatar_url, headers={"User-Agent": "Quickshell-Widget/1.0"})
                        with urllib.request.urlopen(img_req, timeout=6) as img_resp:
                            with open(avatar_file, "wb") as f:
                                f.write(img_resp.read())
                    except Exception:
                        pass
                if avatar_file.exists():
                    avatar_local_path = str(avatar_file)
    except Exception:
        pass
    return {
        "name": name,
        "bio": bio,
        "public_repos": public_repos,
        "avatar": avatar_local_path
    }


def fetch_contributions_api(username, year):
    # Primary API: jogruber github contributions API
    url = f"https://github-contributions-api.jogruber.de/v4/{username}?y={year}"
    req = urllib.request.Request(url, headers={"User-Agent": "Quickshell-Widget/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode())
            total = data.get("total", {}).get(str(year))
            raw_contribs = data.get("contributions", [])
            if raw_contribs:
                return total, raw_contribs
    except Exception as e:
        sys.stderr.write(f"API fetch error: {e}\n")
    return None, None


def fetch_contributions_scrape(username, year):
    # Fallback: Scrape github.com/users/{username}/contributions
    url = f"https://github.com/users/{username}/contributions?from={year}-01-01&to={year}-12-31"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    raw_contribs = []
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode("utf-8")
        
        # Parse data-date, data-level, and commit counts
        # e.g.: data-date="2026-01-01" data-level="1">...<span ...>7 contributions...</span>
        matches = re.findall(r'<td[^>]*data-date="(\d{4}-\d{2}-\d{2})"[^>]*data-level="(\d+)"[^>]*>', html)
        for d, lvl in matches:
            if d.startswith(str(year)):
                # extract count or estimate from level
                raw_contribs.append({
                    "date": d,
                    "count": int(lvl) * 3, # fallback approximate if text not parsed
                    "level": int(lvl)
                })
        # sort by date
        raw_contribs.sort(key=lambda x: x["date"])
        total = sum(x["count"] for x in raw_contribs)
        return total, raw_contribs
    except Exception as e:
        sys.stderr.write(f"Scrape fallback error: {e}\n")
    return None, None


def process_year_contributions(username, year, force_refresh=False):
    cache_file = DATA_DIR / f"github_{username}_{year}.json"
    
    if not force_refresh and cache_file.exists():
        try:
            mtime = cache_file.stat().st_mtime
            if (time.time() - mtime) < CACHE_TTL:
                with open(cache_file, "r") as f:
                    return json.load(f)
        except Exception:
            pass

    # Fetch from API or fallback
    total, raw_days = fetch_contributions_api(username, year)
    if not raw_days:
        total, raw_days = fetch_contributions_scrape(username, year)

    if not raw_days and cache_file.exists():
        # Fall back to stale cache if network failed
        try:
            with open(cache_file, "r") as f:
                return json.load(f)
        except Exception:
            pass

    # Map raw days by date "YYYY-MM-DD"
    day_map = {item["date"]: item for item in (raw_days or [])}
    
    profile = fetch_user_profile(username)
    
    # Generate complete day-by-day calendar for ONLY the current year
    d0 = datetime.date(year, 1, 1)
    d_end = datetime.date(year, 12, 31)
    today = datetime.date.today()
    today_str = today.strftime("%Y-%m-%d")

    # Sunday-first day index: Sunday=0, Monday=1, ..., Saturday=6
    # python weekday(): Monday=0 ... Sunday=6
    def sun_day_idx(d):
        return (d.weekday() + 1) % 7

    first_col_day = sun_day_idx(d0)

    days_list = []
    total_count = 0
    longest_streak = 0
    current_run = 0

    curr = d0
    while curr <= d_end:
        d_str = curr.strftime("%Y-%m-%d")
        item = day_map.get(d_str, {"count": 0, "level": 0})
        cnt = int(item.get("count", 0))
        lvl = int(item.get("level", 0))
        
        # day index from Jan 1
        day_offset = (curr - d0).days
        col_idx = (day_offset + first_col_day) // 7
        row_idx = sun_day_idx(curr)
        
        is_today = (d_str == today_str)
        is_future = (curr > today)

        if not is_future:
            total_count += cnt
            if cnt > 0:
                current_run += 1
                if current_run > longest_streak:
                    longest_streak = current_run
            else:
                current_run = 0

        days_list.append({
            "date": d_str,
            "day": curr.day,
            "month": curr.month,
            "count": cnt,
            "level": lvl if not is_future else 0,
            "col": col_idx,
            "row": row_idx,
            "isToday": is_today,
            "isFuture": is_future,
            "label": curr.strftime("%a, %b %d, %Y")
        })

        curr += datetime.timedelta(days=1)

    # Current streak calculation (backwards from today)
    current_streak = 0
    for d_obj in reversed(days_list):
        if d_obj["isFuture"]:
            continue
        # If today has 0 commits, keep yesterday's streak alive
        if d_obj["isToday"] and d_obj["count"] == 0:
            continue
        if d_obj["count"] > 0:
            current_streak += 1
        else:
            break

    # Month header offsets for 2026
    months_list = []
    for m in range(1, 13):
        dm = datetime.date(year, m, 1)
        col = ((dm - d0).days + first_col_day) // 7
        months_list.append({
            "name": dm.strftime("%b"),
            "col": col
        })

    total_cols = ((d_end - d0).days + first_col_day) // 7 + 1

    payload = {
        "year": year,
        "username": username,
        "name": profile.get("name", username),
        "bio": profile.get("bio", ""),
        "avatar": profile.get("avatar", ""),
        "public_repos": profile.get("public_repos", 0),
        "total": total if (total is not None and total > 0) else total_count,
        "currentStreak": current_streak,
        "longestStreak": longest_streak,
        "today": today_str,
        "totalCols": total_cols,
        "months": months_list,
        "days": days_list,
        "updatedAt": datetime.datetime.now().strftime("%H:%M")
    }

    try:
        with open(cache_file, "w") as f:
            json.dump(payload, f, indent=2)
    except Exception as e:
        sys.stderr.write(f"Cache write error: {e}\n")

    return payload


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"
    username = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else get_default_username()
    year = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else datetime.date.today().year

    force = (cmd == "fetch")
    result = process_year_contributions(username, year, force_refresh=force)
    print(json.dumps(result))


if __name__ == "__main__":
    main()
