#!/usr/bin/env python3
"""
wifi-details.py: Returns comprehensive Wi-Fi telemetry and nearby networks as JSON
Used by Quickshell's WifiWidget.
"""
import subprocess
import json

def get_wifi_telemetry():
    result = {
        "connected": False,
        "radioOn": True,
        "ssid": "Disconnected",
        "bssid": "",
        "channel": "",
        "freq": "",
        "band": "",
        "rate": "",
        "signal": 0,
        "security": "",
        "device": "wlp0s20f3",
        "ip": "No IP",
        "gateway": "",
        "dns": "",
        "nearby": []
    }

    # 1. Radio status
    try:
        radio = subprocess.check_output(["nmcli", "radio", "wifi"], timeout=1).decode().strip()
        result["radioOn"] = (radio == "enabled")
    except Exception:
        pass

    if not result["radioOn"]:
        result["ssid"] = "Wi-Fi Off"
        return result

    # 2. Scan APs and Active connection
    try:
        raw = subprocess.check_output(
            ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,FREQ,RATE,SECURITY,CHAN,DEVICE,BSSID", "dev", "wifi"],
            timeout=3
        ).decode()

        seen_ssids = set()
        for line in raw.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(":")
            if len(parts) < 8:
                continue

            active = (parts[0] == "yes")
            ssid = parts[1]
            sig = parts[2]
            freq = parts[3]
            rate = parts[4]
            sec = parts[5]
            chan = parts[6]
            dev = parts[7]
            bssid = ":".join(parts[8:]).replace("\\", "")

            band_label = "5 GHz" if ("5" in freq[:2] or (chan.isdigit() and int(chan) > 14)) else "2.4 GHz"

            if active and not result["connected"]:
                result["connected"] = True
                result["ssid"] = ssid if ssid else "Hidden Network"
                result["bssid"] = bssid
                result["channel"] = chan
                result["freq"] = freq
                result["band"] = band_label
                result["rate"] = rate
                result["signal"] = int(sig) if sig.isdigit() else 0
                result["security"] = sec if sec else "None"
                if dev:
                    result["device"] = dev

            # Collect unique nearby SSIDs
            if ssid and ssid != "--" and ssid not in seen_ssids:
                seen_ssids.add(ssid)
                result["nearby"].append({
                    "ssid": ssid,
                    "signal": int(sig) if sig.isdigit() else 0,
                    "band": band_label,
                    "rate": rate,
                    "security": sec if sec else "Open",
                    "active": active
                })

    except Exception:
        pass

    # Sort nearby networks: active first, then descending signal strength
    result["nearby"].sort(key=lambda x: (not x["active"], -x["signal"]))
    result["nearby"] = result["nearby"][:5]

    # 3. IP address for wireless device
    try:
        ip_out = subprocess.check_output(
            ["ip", "-4", "-o", "addr", "show", result["device"], "scope", "global"],
            timeout=1
        ).decode()
        for l in ip_out.strip().split("\n"):
            p = l.split()
            if len(p) >= 4:
                result["ip"] = p[3].split("/")[0]
                break
    except Exception:
        pass

    # 4. Gateway IP
    try:
        gw_out = subprocess.check_output(["ip", "route", "show", "default"], timeout=1).decode()
        p = gw_out.strip().split()
        if len(p) >= 3:
            result["gateway"] = p[2]
    except Exception:
        pass

    # 5. DNS
    try:
        with open("/etc/resolv.conf", "r") as f:
            for l in f:
                if l.startswith("nameserver"):
                    ns = l.split()[1]
                    if ns != "127.0.0.53":
                        result["dns"] = ns
                        break
                    else:
                        result["dns"] = "Local (systemd)"
    except Exception:
        pass

    return result

if __name__ == "__main__":
    print(json.dumps(get_wifi_telemetry()))
