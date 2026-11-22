#!/usr/bin/env python3
"""
github-activity.py
Fetches GitHub Pull Requests, Notifications (with optional PAT), and Public Activity
for Quickshell Developer Desktop Widgets.
"""

import sys
import os
import json
import time
import datetime
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path

DATA_DIR = Path.home() / ".local" / "share" / "desktop-widgets"
DATA_DIR.mkdir(parents=True, exist_ok=True)
CACHE_TTL = 300  # 5 minutes


def get_default_username():
    try:
        import subprocess
        res = subprocess.run(["git", "config", "--get", "github.user"], capture_output=True, text=True)
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    return "dferram"


def get_github_token():
    for env_key in ("GITHUB_TOKEN", "GH_TOKEN"):
        val = os.environ.get(env_key, "").strip()
        if val:
            return val
    token_file = DATA_DIR / "github_token"
    if token_file.exists():
        try:
            val = token_file.read_text().strip().splitlines()[0].strip()
            if val:
                return val
        except Exception:
            pass
    return ""


def api_get(url, token="", timeout=7):
    headers = {
        "User-Agent": "Quickshell-Dev-Widget/1.0",
        "Accept": "application/vnd.github+json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def format_relative_age(iso_str):
    if not iso_str:
        return ""
    try:
        dt = datetime.datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.datetime.now(datetime.timezone.utc)
        secs = max(0, int((now - dt).total_seconds()))
        if secs < 60:
            return "now"
        if secs < 3600:
            return f"{secs // 60}m"
        if secs < 86400:
            return f"{secs // 3600}h"
        days = secs // 86400
        if days < 30:
            return f"{days}d"
        if days < 365:
            return f"{days // 30}mo"
        return f"{days // 365}y"
    except Exception:
        return ""


def fetch_prs(username, token=""):
    q = urllib.parse.quote(f"involves:{username} type:pr")
    url = f"https://api.github.com/search/issues?q={q}&sort=updated&order=desc&per_page=8"
    prs = []
    open_count = 0
    try:
        data = api_get(url, token=token)
        for item in data.get("items", []):
            repo_url = item.get("repository_url", "")
            parts = repo_url.split("/")
            repo_short = parts[-1] if parts else ""
            full_repo = "/".join(parts[-2:]) if len(parts) >= 2 else repo_short
            raw_state = item.get("state", "open")
            pr_meta = item.get("pull_request") or {}
            if pr_meta.get("merged_at"):
                norm_state = "merged"
            elif item.get("draft"):
                norm_state = "draft"
            else:
                norm_state = raw_state
            if norm_state in ("open", "draft"):
                open_count += 1
            author = (item.get("user") or {}).get("login", "")
            prs.append({
                "title": item.get("title", ""),
                "repo": repo_short,
                "fullRepo": full_repo,
                "number": int(item.get("number", 0)),
                "state": norm_state,
                "author": author,
                "isMine": author.lower() == username.lower(),
                "ago": format_relative_age(item.get("updated_at", "")),
                "url": item.get("html_url", f"https://github.com/{full_repo}")
            })
    except Exception as e:
        sys.stderr.write(f"PR fetch error: {e}\n")
    return open_count, prs


def api_url_to_web(api_url, full_repo):
    if not api_url:
        return f"https://github.com/{full_repo}" if full_repo else "https://github.com/notifications"
    web = api_url.replace("https://api.github.com/repos/", "https://github.com/")
    web = web.replace("/pulls/", "/pull/")
    return web


def fetch_notifications_or_activity(username, token=""):
    if token:
        try:
            items = api_get("https://api.github.com/notifications?all=false&per_page=8", token=token)
            notifs = []
            for n in items:
                subj = n.get("subject") or {}
                repo_obj = n.get("repository") or {}
                full_repo = repo_obj.get("full_name", "")
                repo_name = repo_obj.get("name", full_repo)
                notifs.append({
                    "title": subj.get("title", ""),
                    "repo": repo_name,
                    "kind": subj.get("type", "Notification"),
                    "reason": n.get("reason", "subscribed"),
                    "unread": bool(n.get("unread", True)),
                    "ago": format_relative_age(n.get("updated_at", "")),
                    "url": api_url_to_web(subj.get("url", ""), full_repo)
                })
            return True, len(notifs), notifs
        except Exception as e:
            sys.stderr.write(f"Notif fetch error: {e}\n")

    # Fallback without PAT: public user + received events stream
    events_out = []
    try:
        items = api_get(f"https://api.github.com/users/{username}/events/public?per_page=10")
        for ev in items[:8]:
            etype = ev.get("type", "")
            repo_full = (ev.get("repo") or {}).get("name", "")
            repo_short = repo_full.split("/")[-1] if repo_full else ""
            payload = ev.get("payload") or {}
            if etype == "PushEvent":
                commits = payload.get("size") or len(payload.get("commits") or [])
                branch = (payload.get("ref") or "").replace("refs/heads/", "")
                summary = f"Pushed {commits or 1} commit(s) to {branch or 'branch'}"
                kind = "Push"
            elif etype == "PullRequestEvent":
                action = payload.get("action", "updated")
                pr_num = (payload.get("pull_request") or {}).get("number") or payload.get("number", "")
                summary = f"PR #{pr_num} {action}"
                kind = "PR"
            elif etype == "IssuesEvent":
                action = payload.get("action", "updated")
                iss_num = (payload.get("issue") or {}).get("number", "")
                summary = f"Issue #{iss_num} {action}"
                kind = "Issue"
            elif etype == "CreateEvent":
                ref_type = payload.get("ref_type", "branch")
                ref = payload.get("ref") or ""
                summary = f"Created {ref_type} {ref}".strip()
                kind = "Create"
            else:
                summary = etype.replace("Event", "")
                kind = "Event"
            events_out.append({
                "title": summary,
                "repo": repo_short,
                "kind": kind,
                "reason": "public",
                "unread": False,
                "ago": format_relative_age(ev.get("created_at", "")),
                "url": f"https://github.com/{repo_full}" if repo_full else f"https://github.com/{username}"
            })
    except Exception as e:
        sys.stderr.write(f"Events fetch error: {e}\n")
    return bool(token), 0, events_out


def get_activity(username, force=False):
    cache_file = DATA_DIR / f"github_activity_{username}.json"
    token = get_github_token()

    if not force and cache_file.exists():
        try:
            if (time.time() - cache_file.stat().st_mtime) < CACHE_TTL:
                cached = json.loads(cache_file.read_text())
                # Re-fetch if token presence changed
                if bool(cached.get("hasToken", False)) == bool(token):
                    return cached
        except Exception:
            pass

    open_pr_count, prs = fetch_prs(username, token=token)
    has_token, unread_count, notifs = fetch_notifications_or_activity(username, token=token)

    result = {
        "username": username,
        "hasToken": has_token,
        "openPrCount": open_pr_count,
        "prs": prs,
        "unreadCount": unread_count,
        "notifications": notifs,
        "updatedAt": datetime.datetime.now().strftime("%H:%M")
    }

    try:
        cache_file.write_text(json.dumps(result, indent=2))
    except Exception:
        pass
    return result


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"
    username = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else get_default_username()
    force = (cmd == "fetch")
    print(json.dumps(get_activity(username, force=force)))


if __name__ == "__main__":
    main()
