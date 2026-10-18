#!/usr/bin/env python3
"""
battery-details.py: Returns detailed battery health, hardware stats and telemetry as JSON
Used by Quickshell's BatteryWidget.
"""
import os
import json
import subprocess

def get_battery_info():
    base = "/sys/class/power_supply/BAT0"
    if not os.path.exists(base):
        # Check other possible names like BAT1
        for f in os.listdir("/sys/class/power_supply") if os.path.exists("/sys/class/power_supply") else []:
            if f.startswith("BAT"):
                base = os.path.join("/sys/class/power_supply", f)
                break

    if not os.path.exists(base):
        return {"present": False}

    def read_val(f, default=""):
        p = os.path.join(base, f)
        if os.path.exists(p):
            try:
                with open(p) as fp:
                    return fp.read().strip()
            except Exception:
                pass
        return default

    status = read_val("status", "Unknown")
    capacity_str = read_val("capacity", "0")
    try:
        capacity = int(capacity_str)
    except Exception:
        capacity = 0

    cycle_count_str = read_val("cycle_count", "0")
    try:
        cycle_count = int(cycle_count_str)
    except Exception:
        cycle_count = 0

    # Wh or uWh
    def to_wh(val_str):
        try:
            return round(int(val_str) / 1e6, 1)
        except Exception:
            return 0.0

    energy_now = to_wh(read_val("energy_now", "0"))
    energy_full = to_wh(read_val("energy_full", "0"))
    energy_design = to_wh(read_val("energy_full_design", "0"))

    # If battery uses charge_* instead of energy_*
    if energy_now == 0.0 and os.path.exists(os.path.join(base, "charge_now")):
        v = float(read_val("voltage_now", "11000000")) / 1e6
        energy_now = round((float(read_val("charge_now", "0")) / 1e6) * v, 1)
        energy_full = round((float(read_val("charge_full", "0")) / 1e6) * v, 1)
        energy_design = round((float(read_val("charge_full_design", "0")) / 1e6) * v, 1)

    try:
        power_now = round(int(read_val("power_now", "0")) / 1e6, 1)
    except Exception:
        power_now = 0.0

    try:
        voltage_now = round(int(read_val("voltage_now", "0")) / 1e6, 2)
    except Exception:
        voltage_now = 0.0

    health_pct = round((energy_full / energy_design) * 100, 1) if energy_design > 0 else 100.0

    tech = read_val("technology", "Li-ion")
    model = read_val("model_name", "Battery")
    manufacturer = read_val("manufacturer", "")

    # Thresholds
    th_start = read_val("charge_control_start_threshold", "")
    th_end = read_val("charge_control_end_threshold", "")
    thresholds = f"{th_start}% - {th_end}%" if (th_start and th_end) else ""

    is_charging = status.lower() in ("charging", "full")

    # Time remaining calculation if power_now > 0
    time_str = ""
    if power_now > 0.5:
        if not is_charging and energy_now > 0:
            hours = energy_now / power_now
            h = int(hours)
            m = int((hours - h) * 60)
            time_str = f"{h}h {m:02d}m" if h > 0 else f"{m} mins"
        elif is_charging and energy_full > energy_now:
            hours = (energy_full - energy_now) / power_now
            h = int(hours)
            m = int((hours - h) * 60)
            time_str = f"{h}h {m:02d}m" if h > 0 else f"{m} mins"

    power_profile = "balanced"
    try:
        power_profile = subprocess.check_output(["powerprofilesctl", "get"], timeout=1).decode().strip()
    except Exception:
        pass

    return {
        "present": True,
        "status": status,
        "capacity": capacity,
        "cycle_count": cycle_count,
        "energy_now_wh": energy_now,
        "energy_full_wh": energy_full,
        "energy_design_wh": energy_design,
        "power_now_w": power_now,
        "voltage_now_v": voltage_now,
        "health_pct": health_pct,
        "technology": tech,
        "model": model,
        "manufacturer": manufacturer,
        "thresholds": thresholds,
        "time_str": time_str,
        "is_charging": is_charging,
        "power_profile": power_profile
    }

if __name__ == "__main__":
    print(json.dumps(get_battery_info()))
