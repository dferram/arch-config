import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// ==============================================================================
// LOCK CONTEXT — shared state for every lock surface (one per monitor)
// Auth (PAM password + fprintd fingerprint), reveal state, clock, agent status.
// ==============================================================================
Scope {
    id: ctx

    // Set by LockScreen: true while the session lock is engaged
    property bool locked: false
    signal unlocked()

    // --- Reveal state: false = monumental OLED flip clock, true = control panel ---
    property bool revealed: false
    property string password: ""
    property bool authBusy: pam.active
    property bool authFailed: false
    property string statusText: ""
    property int failCount: 0

    function reveal() {
        revealed = true;
        idleTimer.restart();
    }
    function hide() {
        if (pam.active) return;
        revealed = false;
        password = "";
        authFailed = false;
        statusText = "";
    }
    function poke() { idleTimer.restart(); }

    function submit() {
        if (pam.active) return;
        if (password.length === 0) return;
        authFailed = false;
        statusText = "Verifying…";
        pam.start();
    }

    onLockedChanged: {
        if (locked) {
            revealed = false;
            password = "";
            authFailed = false;
            statusText = "";
            failCount = 0;
            refreshAgents();
            if (fingerprintAvailable) {
                fprintProc.running = true;
            }
        } else {
            if (pam.active) pam.abort();
            fprintProc.running = false;
        }
    }

    // Return to the clean OLED clock after 20 s without interaction
    Timer {
        id: idleTimer
        interval: 20000
        onTriggered: ctx.hide()
    }

    // --------------------------------------------------------------------------
    // PAM password authentication (reuses /etc/pam.d/hyprlock -> login)
    // --------------------------------------------------------------------------
    PamContext {
        id: pam
        config: "hyprlock"

        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(ctx.password);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                ctx.statusText = "";
                ctx.password = "";
                ctx.unlocked();
            } else {
                ctx.failCount += 1;
                ctx.authFailed = true;
                ctx.password = "";
                ctx.statusText = "Incorrect password";
                ctx.poke();
            }
        }

        onError: err => {
            ctx.authFailed = true;
            ctx.password = "";
            ctx.statusText = "Authentication error";
        }
    }

    // --------------------------------------------------------------------------
    // Fingerprint unlock (Goodix sensor via fprintd), loops while locked
    // --------------------------------------------------------------------------
    property bool fingerprintAvailable: true

    Process {
        id: fprintProc
        command: ["fprintd-verify"]
        // No 'running:' binding here to prevent QML from breaking it on exit
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("verify-no-match") !== -1) {
                    ctx.authFailed = true;
                    ctx.statusText = "Fingerprint not recognized";
                    if (!ctx.revealed) ctx.reveal();
                }
                if (line.indexOf("No devices available") !== -1) ctx.fingerprintAvailable = false;
            }
        }
        onExited: (code, status) => {
            fprintProc.running = false; // ensure clean state
            if (!ctx.locked) return;
            if (code === 0) {
                ctx.unlocked();
                return;
            }
            fprintRetry.restart();
        }
    }
    Timer {
        id: fprintRetry
        interval: 1200
        onTriggered: if (ctx.locked && ctx.fingerprintAvailable) fprintProc.running = true
    }

    // --------------------------------------------------------------------------
    // Clock
    // --------------------------------------------------------------------------
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }
    property date now: sysClock.date

    // Agent processes are sampled only while locked. No prompt/title content is read.
    property var agents: []
    property bool agentsAvailable: false
    function refreshAgents() {
        if (!agentProc.running) agentProc.running = true;
    }
    Component.onCompleted: refreshAgents()
    Process {
        id: agentProc
        // shellPath stays on disk across reloads; resolvedUrl may use qs-vfs:.
        command: ["python3", Quickshell.shellPath("scripts/agent-status.py")]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Agent status helper:", text.trim());
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!Array.isArray(result.agents) || typeof result.available !== "boolean")
                        throw new Error("Invalid agent status response");
                    ctx.agents = result.agents;
                    ctx.agentsAvailable = result.available;
                } catch (e) {
                    ctx.agents = [];
                    ctx.agentsAvailable = false;
                }
            }
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: ctx.locked
        onTriggered: ctx.refreshAgents()
    }

    readonly property string userName: Quickshell.env("USER") || "ferram"
}
