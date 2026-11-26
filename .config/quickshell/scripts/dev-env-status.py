#!/usr/bin/env python3
"""
dev-env-status.py
Fast local developer environment scanner for Quickshell desktop widgets:
  - ports: listening local dev TCP ports (ss -tlnpH) + running Docker containers
  - git:   local repositories status (branch, dirty counts, ahead/behind, last commit)
"""

import sys
import os
import json
import re
import time
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

WELL_KNOWN_DEV_PORTS = {
    80, 443, 3000, 3001, 3306, 4000, 4173, 4200, 4321,
    5000, 5001, 5173, 5174, 5432, 5500, 6379, 8000, 8080,
    8081, 8443, 8888, 9000, 9090, 9222, 11434, 27017
}

IGNORED_PROCS = {
    "systemd-resolve", "NetworkManager", "cupsd", "avahi-daemon",
    "sshd", "dbus-daemon", "kdeconnectd", "spotify"
}

HTTP_HINT_PORTS = {80, 3000, 3001, 4000, 4173, 4200, 4321, 5000, 5001, 5050, 5173, 5174, 5500, 8000, 8080, 8081, 8888, 9000, 9090}

PORT_FALLBACK_LABELS = {
    80: ("HTTP", "web"),
    443: ("HTTPS", "web"),
    3306: ("MySQL", "mysql"),
    5050: ("pgAdmin", "pgadmin"),
    5173: ("Vite", "vite"),
    5432: ("PostgreSQL", "postgresql"),
    5760: ("ArduPilot SITL", "sitl"),
    5762: ("ArduPilot SITL", "sitl"),
    5763: ("ArduPilot SITL", "sitl"),
    6379: ("Redis", "redis"),
    8000: ("Backend API", "python"),
    8080: ("HTTP / Proxy", "web"),
    9000: ("Portainer / MinIO", "docker"),
    11434: ("Ollama", "ollama"),
    27017: ("MongoDB", "mongodb"),
}

IMAGE_SERVICE_MAP = (
    ("pgadmin", "pgAdmin", True, "pgadmin"),
    ("postgres", "PostgreSQL", False, "postgresql"),
    ("postgis", "PostGIS", False, "postgresql"),
    ("mysql", "MySQL", False, "mysql"),
    ("mariadb", "MariaDB", False, "mysql"),
    ("redis", "Redis", False, "redis"),
    ("mongo", "MongoDB", False, "mongodb"),
    ("nginx", "Nginx", True, "web"),
    ("caddy", "Caddy", True, "web"),
    ("traefik", "Traefik", True, "web"),
    ("minio", "MinIO", True, "docker"),
    ("grafana", "Grafana", True, "web"),
    ("prometheus", "Prometheus", True, "web"),
    ("portainer", "Portainer", True, "docker"),
    ("ollama", "Ollama", True, "ollama"),
    ("rabbitmq", "RabbitMQ", True, "docker"),
    ("node", "Node", True, "node"),
    ("python", "Python", True, "python"),
)


def _read_proc_info(pid):
    """Read cmdline and cwd basename for a given PID."""
    cmdline = ""
    cwd_name = ""
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
        cmdline = raw.replace(b"\x00", b" ").decode("utf-8", errors="replace").strip()
    except Exception:
        pass
    try:
        cwd = os.readlink(f"/proc/{pid}/cwd")
        base = os.path.basename(cwd.rstrip("/"))
        if base and cwd not in ("/", str(Path.home())):
            cwd_name = base
    except Exception:
        pass
    return cmdline, cwd_name


def _identify_process(proc_col, port):
    """Return (label, is_http_hint, icon_key) from ss process column and /proc/<pid>."""
    pairs = re.findall(r'\("([^"]+)",pid=(\d+)', proc_col)
    if not pairs:
        label, icon_key = PORT_FALLBACK_LABELS.get(port, ("service", "port"))
        return label, False, icon_key

    proc = pairs[0][0]
    cmdline = ""
    cwd_name = ""
    for _, pid in pairs:
        cl, cw = _read_proc_info(pid)
        if cl:
            cmdline = cl
            cwd_name = cw
            break

    low_cl = cmdline.lower()
    low_proc = proc.lower()
    label = proc
    http_hint = False
    icon_key = "port"

    if "pgadmin" in low_cl or "pgadmin" in low_proc:
        label = "pgAdmin"
        http_hint = True
        icon_key = "pgadmin"
    elif any(k in low_proc for k in ("node", "bun", "deno")):
        http_hint = True
        if "vite" in low_cl:
            label = "Vite"
            icon_key = "vite"
        elif "next" in low_cl:
            label = "Next.js"
            icon_key = "node"
        elif "nuxt" in low_cl:
            label = "Nuxt"
            icon_key = "node"
        elif "astro" in low_cl:
            label = "Astro"
            icon_key = "node"
        elif "webpack" in low_cl or "react-scripts" in low_cl:
            label = "React"
            icon_key = "node"
        else:
            label = "Node"
            icon_key = "node"
    elif "python" in low_proc or low_proc in ("uvicorn", "gunicorn"):
        http_hint = True
        icon_key = "python"
        if "uvicorn" in low_cl or low_proc == "uvicorn":
            label = "Uvicorn"
        elif "gunicorn" in low_cl or low_proc == "gunicorn":
            label = "Gunicorn"
        elif "flask" in low_cl:
            label = "Flask"
        elif "manage.py" in low_cl or "django" in low_cl:
            label = "Django"
        elif "streamlit" in low_cl:
            label = "Streamlit"
        elif "jupyter" in low_cl:
            label = "Jupyter"
        elif "http.server" in low_cl:
            label = "Python HTTP"
        else:
            label = "Python"
    elif low_proc == "apm" or "ardupilot" in low_cl or "dronekit" in low_cl:
        label = "ArduPilot SITL"
        icon_key = "sitl"
    elif "docker" in low_proc:
        label = "Docker"
        icon_key = "docker"
    elif "postgres" in low_proc:
        label = "PostgreSQL"
        icon_key = "postgresql"
    elif "redis" in low_proc:
        label = "Redis"
        icon_key = "redis"
    elif "mongod" in low_proc:
        label = "MongoDB"
        icon_key = "mongodb"
    elif "ollama" in low_proc:
        label = "Ollama"
        http_hint = True
        icon_key = "ollama"
    elif "nginx" in low_proc:
        label = "Nginx"
        http_hint = True
        icon_key = "web"
    elif "caddy" in low_proc:
        label = "Caddy"
        http_hint = True
        icon_key = "web"

    if cwd_name and label != "ArduPilot SITL" and cwd_name.lower() not in label.lower():
        label = f"{label} · {cwd_name}"

    return label, http_hint, icon_key


def _identify_docker_port(name, image, container_port):
    """Return (label, is_http, icon_key) for a Docker-mapped host port."""
    low_img = image.lower()
    service = ""
    http_hint = container_port in (80, 443, 3000, 5000, 5050, 5173, 8000, 8080)
    icon_key = "docker"
    for key, friendly, is_http, key_icon in IMAGE_SERVICE_MAP:
        if key in low_img:
            service = friendly
            http_hint = http_hint or is_http
            icon_key = key_icon
            break
    if not service:
        service = image.split(":")[0]

    if service.lower() in name.lower():
        return f"{service} (docker)", http_hint, icon_key
    return f"{service} · {name}", http_hint, icon_key


def format_age_ts(epoch):
    if not epoch:
        return ""
    secs = max(0, int(time.time() - epoch))
    if secs < 60:
        return "now"
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        return f"{secs // 3600}h"
    days = secs // 86400
    if days < 30:
        return f"{days}d"
    return f"{days // 30}mo"


def scan_ports():
    containers = []
    docker_running = False
    docker_port_map = {}
    try:
        dres = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"],
            capture_output=True,
            text=True,
            timeout=1.5
        )
        if dres.returncode == 0:
            docker_running = True
            for line in dres.stdout.splitlines():
                segs = line.split("\t")
                if len(segs) >= 3:
                    name = segs[0]
                    image = segs[1].split("/")[-1]
                    status = segs[2]
                    ports_str = segs[3] if len(segs) > 3 else ""
                    c_icon = "docker"
                    low_img = image.lower()
                    for key, _, _, key_icon in IMAGE_SERVICE_MAP:
                        if key in low_img:
                            c_icon = key_icon
                            break
                    containers.append({
                        "name": name,
                        "image": image,
                        "status": status,
                        "icon": c_icon
                    })
                    for hp, cp in re.findall(r"(?:[\d.]+|\[::\]):(\d+)->(\d+)/tcp", ports_str):
                        hport = int(hp)
                        if hport not in docker_port_map:
                            docker_port_map[hport] = _identify_docker_port(name, image, int(cp))
    except Exception:
        pass

    ports_map = {}
    try:
        res = subprocess.run(["ss", "-tlnpH"], capture_output=True, text=True, timeout=2)
        for line in res.stdout.splitlines():
            parts = line.split()
            if len(parts) < 4:
                continue
            local_addr = parts[3]
            m_port = re.search(r":(\d+)$", local_addr)
            if not m_port:
                continue
            port = int(m_port.group(1))
            if port in (22, 53, 631):
                continue
            # Keep dev ports (< 10000 or well-known DB/Ollama/Mongo) and skip random high ephemeral ports
            if port not in WELL_KNOWN_DEV_PORTS and not (3000 <= port <= 9999):
                continue

            proc_col = " ".join(parts[5:]) if len(parts) > 5 else ""
            m_proc = re.search(r'\(\("([^"]+)"', proc_col)
            raw_proc = m_proc.group(1) if m_proc else ""
            if raw_proc in IGNORED_PROCS:
                continue

            if port in docker_port_map and (not raw_proc or "docker" in raw_proc.lower()):
                label, proc_http, icon_key = docker_port_map[port]
            else:
                label, proc_http, icon_key = _identify_process(proc_col, port)

            is_http = port in HTTP_HINT_PORTS or proc_http
            if port not in ports_map:
                ports_map[port] = {
                    "port": port,
                    "process": label,
                    "icon": icon_key,
                    "isHttp": bool(is_http),
                    "url": f"http://localhost:{port}" if is_http else f"localhost:{port}"
                }
    except Exception:
        pass

    ports_list = [ports_map[k] for k in sorted(ports_map.keys())]

    return {
        "ports": ports_list,
        "containers": containers,
        "dockerRunning": docker_running
    }


def scan_git_repos(roots=None):
    if not roots:
        roots = [
            Path.home() / "Personal",
            Path.home() / "Colgate-Palmolive",
            Path.home() / "Projects",
        ]

    repo_dirs = []
    for root in roots:
        root_path = Path(root)
        if not root_path.exists():
            continue
        for entry in root_path.iterdir():
            if not entry.is_dir():
                continue
            if (entry / ".git").exists():
                repo_dirs.append(entry)
            else:
                try:
                    for sub in entry.iterdir():
                        if sub.is_dir() and (sub / ".git").exists():
                            repo_dirs.append(sub)
                except Exception:
                    pass

    def inspect_repo(rdir):
        try:
            st = subprocess.run(
                ["git", "-C", str(rdir), "status", "--porcelain=v1", "-b"],
                capture_output=True,
                text=True,
                timeout=1.5
            )
            if st.returncode != 0:
                return None
            lines = st.stdout.splitlines()
            branch = "main"
            ahead = 0
            behind = 0
            if lines and lines[0].startswith("## "):
                hdr = lines[0][3:]
                branch_part = hdr.split("...")[0].strip()
                if branch_part.startswith("No commits yet on "):
                    branch = branch_part.replace("No commits yet on ", "").strip()
                else:
                    branch = branch_part
                m_ah = re.search(r"ahead (\d+)", hdr)
                m_bh = re.search(r"behind (\d+)", hdr)
                if m_ah:
                    ahead = int(m_ah.group(1))
                if m_bh:
                    behind = int(m_bh.group(1))

            modified = 0
            untracked = 0
            for ln in lines[1:]:
                if ln.startswith("??"):
                    untracked += 1
                elif ln.strip():
                    modified += 1
            dirty = modified + untracked

            lg = subprocess.run(
                ["git", "-C", str(rdir), "log", "-1", "--format=%ct"],
                capture_output=True,
                text=True,
                timeout=1.0
            )
            ts = int(lg.stdout.strip()) if lg.returncode == 0 and lg.stdout.strip().isdigit() else 0

            return {
                "name": rdir.name,
                "path": str(rdir),
                "branch": branch,
                "modified": modified,
                "untracked": untracked,
                "dirty": dirty,
                "ahead": ahead,
                "behind": behind,
                "ts": ts,
                "ago": format_age_ts(ts)
            }
        except Exception:
            return None

    repos = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        for res in pool.map(inspect_repo, repo_dirs):
            if res is not None:
                repos.append(res)
    dirty_repos = sum(1 for r in repos if r["dirty"] > 0)

    repos.sort(key=lambda r: (0 if r["dirty"] > 0 else 1, -r["ts"], r["name"].lower()))
    return {
        "repos": repos,
        "dirtyCount": dirty_repos,
        "totalCount": len(repos)
    }


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "ports"
    if mode == "git":
        print(json.dumps(scan_git_repos()))
    else:
        print(json.dumps(scan_ports()))


if __name__ == "__main__":
    main()
