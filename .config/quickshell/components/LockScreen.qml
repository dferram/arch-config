import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// ==============================================================================
// LOCK SCREEN — ext-session-lock via Quickshell (replaces hyprlock for Super+L)
// IPC:  qs ipc call lock lock      -> engage
//       qs ipc call lock isLocked  -> "true" / "false"
// hyprlock.conf remains untouched as a fallback when Quickshell is not running.
// ==============================================================================
Scope {
    id: root

    LockContext {
        id: lockContext
        locked: sessionLock.locked
        onUnlocked: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurfaceWindow
            color: "black"
            LockSurface {
                anchors.fill: parent
                ctx: lockContext
                screenName: (lockSurfaceWindow.screen && lockSurfaceWindow.screen.name) ? lockSurfaceWindow.screen.name : ""
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock() { sessionLock.locked = true; }
        function isLocked(): bool { return sessionLock.locked; }
        function agentStatus(): string {
            return JSON.stringify({available: lockContext.agentsAvailable, agents: lockContext.agents});
        }
    }
}
