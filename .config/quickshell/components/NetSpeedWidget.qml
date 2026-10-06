import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root
    
    Theme { id: theme }
    
    implicitWidth: pill.implicitWidth
    implicitHeight: 28
    
    property string netText: "0 KB/s"
    property string netIcon: "file:///home/ferram/.local/share/icons/wifi.svg" // We'll just use a generic icon or text
    
    Process {
        id: netProc
        command: ["/home/ferram/.local/bin/net-speed.sh"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let lines = text.trim().split("\n");
                let lastLine = lines[lines.length - 1];
                if (!lastLine) return;
                try {
                    let data = JSON.parse(lastLine);
                    // Format appropriately
                    let rx = data.rx;
                    let display = "";
                    if (rx > 1024) {
                        display = (rx / 1024).toFixed(1) + " MB/s";
                    } else {
                        display = rx + " KB/s";
                    }
                    root.netText = "▼ " + display;
                } catch(e) {}
            }
        }
    }
    
    BarPill {
        id: pill
        text: root.netText
        // We'll use badgeText for the arrow
        badgeText: "🛰️"
        badgeColor: theme.blueLight
    }
}
