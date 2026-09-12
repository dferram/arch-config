import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    Theme { id: theme }

    implicitHeight: pill.implicitHeight
    implicitWidth: pill.implicitWidth

    property bool isNightOn: false

    Process {
        id: statusProc
        command: ["/home/ferram/.local/bin/hypr-night-mode", "status"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                root.isNightOn = text.trim() === "on";
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            if (!statusProc.running) statusProc.running = true;
        }
    }

    Process {
        id: toggleProc
        command: ["/home/ferram/.local/bin/hypr-night-mode", "toggle"]
        onExited: {
            if (!statusProc.running) statusProc.running = true;
        }
    }

    // High quality crisp SVG moon icon
    property string moonIconUri: {
        if (root.isNightOn) {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z' fill='%23f59e0b'/>" +
                   "</svg>";
        } else {
            return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'>" +
                   "<path d='M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z' stroke='%2394a3b8' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/>" +
                   "</svg>";
        }
    }

    BarPill {
        id: pill
        iconSource: root.moonIconUri
        text: root.isNightOn ? "Warm" : "Night"
        accentColor: root.isNightOn ? "#f59e0b" : theme.textMuted
        active: root.isNightOn
        customPadding: 8

        onClicked: {
            root.isNightOn = !root.isNightOn;
            toggleProc.running = true;
        }
    }
}
