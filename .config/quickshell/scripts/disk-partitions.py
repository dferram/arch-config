#!/usr/bin/env python3
"""
disk-partitions.py: Returns disk partition space and mount information as JSON
Used by Quickshell's StorageWidget.
"""
import json
import subprocess
import shutil
import sys

def get_disk_info():
    try:
        raw = subprocess.check_output(
            ["lsblk", "-J", "-b", "-o", "NAME,PATH,MOUNTPOINTS,SIZE,FSTYPE,LABEL,MODEL"],
            timeout=2
        ).decode()
        data = json.loads(raw)
    except Exception as e:
        return {"error": str(e), "partitions": [], "root": None, "total_disk_gb": 0}

    partitions = []
    root_part = None
    total_disk_bytes = 0

    def parse_device(dev):
        nonlocal total_disk_bytes, root_part
        size_bytes = int(dev.get("size") or 0)
        
        # If top-level block device with children
        if "children" in dev:
            total_disk_bytes += size_bytes
            for child in dev["children"]:
                parse_device(child)
            return

        mounts = [m for m in dev.get("mountpoints", []) if m]
        if not mounts and dev.get("mountpoint"):
            mounts.append(dev.get("mountpoint"))

        fstype = dev.get("fstype") or ""
        label = dev.get("label") or ""
        name = dev.get("name") or ""
        path = dev.get("path") or f"/dev/{name}"

        # Ignore tiny recovery/hidden partitions under 200MB or swap
        if fstype == "swap" or size_bytes < 200 * 1024 * 1024:
            return

        total_gb = round(size_bytes / (1024**3), 1)
        used_gb = 0.0
        free_gb = 0.0
        pct = 0
        is_mounted = len(mounts) > 0
        mount_point = mounts[0] if is_mounted else ""

        if is_mounted:
            try:
                usage = shutil.disk_usage(mount_point)
                total_gb = round(usage.total / (1024**3), 1)
                used_gb = round(usage.used / (1024**3), 1)
                free_gb = round(usage.free / (1024**3), 1)
                pct = round((usage.used / usage.total) * 100) if usage.total > 0 else 0
            except Exception:
                pass

        # Human-friendly label
        if mount_point == "/":
            display_label = "Linux (Root)"
        elif mount_point == "/home":
            display_label = "Home"
        elif mount_point == "/boot/efi":
            display_label = "EFI Boot"
        elif label:
            display_label = label
        elif mount_point.startswith("/run/media/") or mount_point.startswith("/media/") or mount_point.startswith("/mnt/"):
            display_label = "Data Drive"
        else:
            display_label = label if label else name

        part_info = {
            "name": name,
            "path": path,
            "mount": mount_point,
            "label": display_label,
            "fstype": fstype.upper() if fstype else "RAW",
            "total_gb": total_gb,
            "used_gb": used_gb,
            "free_gb": free_gb,
            "pct": pct,
            "is_mounted": is_mounted
        }

        if mount_point == "/":
            root_part = part_info

        partitions.append(part_info)

    for dev in data.get("blockdevices", []):
        parse_device(dev)

    # Sort: Root first, then mounted by size, then unmounted
    partitions.sort(key=lambda p: (
        0 if p["mount"] == "/" else (1 if p["is_mounted"] else 2),
        -p["total_gb"]
    ))

    return {
        "total_disk_gb": round(total_disk_bytes / (1024**3), 1),
        "root": root_part,
        "partitions": partitions
    }

if __name__ == "__main__":
    print(json.dumps(get_disk_info()))
