#!/usr/bin/env python3
"""
leetcode-stats.py
Fetches and caches public LeetCode profile stats and daily challenge via GraphQL.
Uses Python 3 stdlib only, no API key or authentication required.
Designed for Quickshell Apple Sonoma Desktop Widgets.
"""

import sys
import json
import time
import datetime
import urllib.request
import urllib.error
from pathlib import Path

DATA_DIR = Path.home() / ".local" / "share" / "desktop-widgets"
DATA_DIR.mkdir(parents=True, exist_ok=True)
CACHE_TTL = 1800  # 30 minutes
REQUEST_TIMEOUT = 30  # Deliberate 30s timeout for slow networks

GRAPHQL_URL = "https://leetcode.com/graphql"
GRAPHQL_QUERY = """
query getLeetCodeData($username: String!) {
  matchedUser(username: $username) {
    username
    profile {
      ranking
      userAvatar
    }
    submitStatsGlobal {
      acSubmissionNum {
        difficulty
        count
      }
    }
    userCalendar {
      streak
      totalActiveDays
      submissionCalendar
    }
  }
  activeDailyCodingChallengeQuestion {
    date
    link
    question {
      title
      titleSlug
      difficulty
      acRate
    }
  }
}
"""


def fetch_leetcode_graphql(username):
    body = json.dumps({
        "query": GRAPHQL_QUERY,
        "variables": {"username": username}
    }).encode("utf-8")
    req = urllib.request.Request(
        GRAPHQL_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
            "Referer": f"https://leetcode.com/u/{username}/",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def parse_payload(raw, username):
    data = raw.get("data") or {}
    user = data.get("matchedUser")
    if not user:
        raise ValueError(f"User '{username}' not found on LeetCode")

    ac_list = (user.get("submitStatsGlobal") or {}).get("acSubmissionNum") or []
    counts = {item.get("difficulty"): int(item.get("count", 0)) for item in ac_list}

    cal = user.get("userCalendar") or {}
    sub_cal_raw = cal.get("submissionCalendar") or "{}"
    try:
        sub_cal = json.loads(sub_cal_raw) if isinstance(sub_cal_raw, str) else (sub_cal_raw or {})
    except Exception:
        sub_cal = {}

    # LeetCode submissionCalendar keys are UTC midnight epoch seconds
    utc_dates = {}
    for ts_str, cnt in sub_cal.items():
        try:
            dt = datetime.datetime.fromtimestamp(int(ts_str), tz=datetime.timezone.utc).strftime("%Y-%m-%d")
            utc_dates[dt] = utc_dates.get(dt, 0) + int(cnt)
        except Exception:
            continue

    today_utc = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
    today_local = datetime.date.today().strftime("%Y-%m-%d")

    daily_raw = data.get("activeDailyCodingChallengeQuestion") or {}
    daily_q = daily_raw.get("question") or {}
    daily_date = daily_raw.get("date") or today_utc
    daily_link = daily_raw.get("link") or ""
    if daily_link and daily_link.startswith("/"):
        daily_url = f"https://leetcode.com{daily_link}"
    elif daily_q.get("titleSlug"):
        daily_url = f"https://leetcode.com/problems/{daily_q['titleSlug']}/"
    else:
        daily_url = "https://leetcode.com/problemset/"

    today_subs = utc_dates.get(today_utc, 0) or utc_dates.get(daily_date, 0) or utc_dates.get(today_local, 0)

    # Compute true current active streak backwards from today UTC (keep yesterday alive if today is 0)
    today_utc_date = datetime.datetime.now(datetime.timezone.utc).date()
    current_streak = 0
    check_day = today_utc_date
    if utc_dates.get(check_day.strftime("%Y-%m-%d"), 0) == 0:
        check_day = today_utc_date - datetime.timedelta(days=1)
    while utc_dates.get(check_day.strftime("%Y-%m-%d"), 0) > 0:
        current_streak += 1
        check_day -= datetime.timedelta(days=1)

    last_active_date = max(utc_dates.keys()) if utc_dates else ""

    return {
        "username": user.get("username") or username,
        "totalSolved": counts.get("All", 0),
        "easySolved": counts.get("Easy", 0),
        "mediumSolved": counts.get("Medium", 0),
        "hardSolved": counts.get("Hard", 0),
        "streak": current_streak,
        "bestStreak": int(cal.get("streak") or 0),
        "totalActiveDays": int(cal.get("totalActiveDays") or 0),
        "lastActiveDate": last_active_date,
        "ranking": int((user.get("profile") or {}).get("ranking") or 0),
        "solvedToday": today_subs > 0,
        "todaySubmissions": today_subs,
        "daily": {
            "date": daily_date,
            "title": daily_q.get("title") or "Daily Challenge",
            "titleSlug": daily_q.get("titleSlug") or "",
            "difficulty": daily_q.get("difficulty") or "Medium",
            "acRate": round(float(daily_q.get("acRate") or 0.0), 1),
            "url": daily_url,
        },
        "updatedAt": datetime.datetime.now().strftime("%H:%M"),
    }


def get_stats(username, force_refresh=False):
    cache_file = DATA_DIR / f"leetcode_{username}.json"

    if not force_refresh and cache_file.exists():
        try:
            if (time.time() - cache_file.stat().st_mtime) < CACHE_TTL:
                with open(cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass

    try:
        raw = fetch_leetcode_graphql(username)
        payload = parse_payload(raw, username)
        try:
            tmp = cache_file.with_suffix(".tmp")
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
            tmp.replace(cache_file)
        except Exception as e:
            sys.stderr.write(f"Cache write error: {e}\n")
        return payload
    except Exception as e:
        sys.stderr.write(f"LeetCode fetch error: {e}\n")
        if cache_file.exists():
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return {"error": str(e), "username": username}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"
    username = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else "dferram"
    force = (cmd == "fetch")
    result = get_stats(username, force_refresh=force)
    print(json.dumps(result))
    if "error" in result:
        sys.exit(1)


if __name__ == "__main__":
    main()
