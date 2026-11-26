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
    property string focusedCountdown: "" // "" | "doomsday" | "nsqk"
    property string password: ""
    property bool authBusy: pam.active
    property bool authFailed: false
    property string statusText: ""
    property int failCount: 0

    // Grace period quick-unlock (double-tap Enter within 1 minute of locking)
    property double lockedAt: 0
    property double lastEnterTime: 0

    function tryQuickUnlock(): bool {
        if (password.length > 0 || failCount > 0) {
            lastEnterTime = 0;
            return false;
        }
        const now = Date.now();
        const lockedDuration = now - lockedAt;
        if (lockedAt > 0 && lockedDuration <= 60000) {
            const delta = now - lastEnterTime;
            lastEnterTime = now;
            if (delta > 30 && delta <= 1200) {
                lastEnterTime = 0;
                ctx.unlocked();
                return true;
            }
        } else {
            lastEnterTime = 0;
        }
        return false;
    }

    function resetQuickUnlock() {
        lastEnterTime = 0;
    }

    function reveal() {
        revealed = true;
        if (focusedCountdown === "") idleTimer.restart();
    }
    function focusCountdown(id) {
        focusedCountdown = id;
        idleTimer.stop();
    }
    function clearFocusedCountdown() {
        if (focusedCountdown === "") return;
        focusedCountdown = "";
        if (revealed) idleTimer.restart();
    }
    function hide() {
        if (pam.active) return;
        focusedCountdown = "";
        revealed = false;
        password = "";
        authFailed = false;
        statusText = "";
    }
    function poke() {
        if (focusedCountdown === "") idleTimer.restart();
    }

    function submit() {
        if (pam.active) return;
        if (password.length === 0) return;
        authFailed = false;
        statusText = "Verifying…";
        pam.start();
    }

    onLockedChanged: {
        if (locked) {
            lockedAt = Date.now();
            lastEnterTime = 0;
            focusedCountdown = "";
            revealed = false;
            password = "";
            authFailed = false;
            statusText = "";
            failCount = 0;
            checkCapsLock();
            refreshAgents();
            refreshReminders();
            refreshWallpaper();
            if (fingerprintEnabled && fingerprintAvailable) {
                fprintProc.running = true;
            } else if (fingerprintEnabled) {
                fprintCheckProc.running = true;
            }
        } else {
            lockedAt = 0;
            lastEnterTime = 0;
            focusedCountdown = "";
            if (pam.active) pam.abort();
            fprintProc.running = false;
        }
    }
    onRevealedChanged: if (revealed) checkCapsLock()

    // Return to the clean OLED clock after 20 s without interaction
    Timer {
        id: idleTimer
        interval: 20000
        onTriggered: {
            if (ctx.focusedCountdown === "") ctx.hide();
        }
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
    // Fingerprint unlock (Goodix sensor via fprintd), disabled until configured
    // --------------------------------------------------------------------------
    property bool fingerprintEnabled: false
    property bool fingerprintAvailable: false

    Process {
        id: fprintCheckProc
        command: ["fprintd-list", ctx.userName]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text || "";
                const hasDevice = t.indexOf("No devices available") === -1;
                const hasFingers = t.indexOf("has no fingers enrolled") === -1 && t.indexOf("Fingerprints for user") !== -1 && /\n\s*-\s+#/.test(t);
                ctx.fingerprintAvailable = ctx.fingerprintEnabled && hasDevice && hasFingers;
                if (ctx.locked && ctx.fingerprintAvailable && !fprintProc.running) {
                    fprintProc.running = true;
                }
            }
        }
    }

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
                if (line.indexOf("No devices available") !== -1 || line.indexOf("has no fingers enrolled") !== -1) {
                    ctx.fingerprintAvailable = false;
                }
            }
        }
        onExited: (code, status) => {
            fprintProc.running = false; // ensure clean state
            if (!ctx.locked) return;
            if (code === 0) {
                ctx.unlocked();
                return;
            }
            if (ctx.fingerprintEnabled && ctx.fingerprintAvailable) fprintRetry.restart();
        }
    }
    Timer {
        id: fprintRetry
        interval: 1200
        onTriggered: if (ctx.locked && ctx.fingerprintEnabled && ctx.fingerprintAvailable) fprintProc.running = true
    }

    // --------------------------------------------------------------------------
    // Caps Lock state
    // --------------------------------------------------------------------------
    property bool capsLock: false
    function checkCapsLock() {
        if (!capsProc.running) capsProc.running = true;
    }
    function toggleCapsLockTentative() {
        ctx.capsLock = !ctx.capsLock;
        capsDelayTimer.restart();
    }
    Timer {
        id: capsDelayTimer
        interval: 100
        onTriggered: ctx.checkCapsLock()
    }
    Timer {
        id: capsPollTimer
        interval: 400
        repeat: true
        running: ctx.locked && ctx.revealed
        onTriggered: ctx.checkCapsLock()
    }
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | grep -q 1 && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                ctx.capsLock = (text.trim() === "1");
            }
        }
        onExited: (code, status) => {
            capsProc.running = false;
        }
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

    // Calendar reminders (same store as the bar clock popup) + current wallpaper.
    property var reminders: []
    function refreshReminders() {
        if (!remProc.running) remProc.running = true;
    }
    Process {
        id: remProc
        command: ["/home/ferram/.local/bin/hypr-reminders", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    ctx.reminders = Array.isArray(r) ? r : [];
                } catch (e) {
                    ctx.reminders = [];
                }
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: ctx.locked
        onTriggered: ctx.refreshReminders()
    }

    property string wallpaperUrl: ""
    function refreshWallpaper() {
        if (!wallProc.running) wallProc.running = true;
    }
    Process {
        id: wallProc
        command: ["sh", "-c", "sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' \"$HOME/.config/hypr/hyprpaper.conf\" | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                ctx.wallpaperUrl = p !== "" ? "file://" + encodeURI(p) : "";
            }
        }
    }

    // Automatically pick the single countdown with the closest upcoming date
    readonly property string closestCountdown: {
        const nowMs = ctx.now ? ctx.now.getTime() : Date.now();

        function findReminderDate(keywords, fallbackDate) {
            if (ctx.reminders && Array.isArray(ctx.reminders)) {
                for (let i = 0; i < ctx.reminders.length; i++) {
                    const r = ctx.reminders[i];
                    const title = (r.title || "").toLowerCase();
                    const cat = (r.category || "").toLowerCase();
                    let matched = false;
                    for (let k = 0; k < keywords.length; k++) {
                        if (title.indexOf(keywords[k]) !== -1 || cat === keywords[k]) {
                            matched = true;
                            break;
                        }
                    }
                    if (matched && r.date) {
                        const parts = r.date.split("-");
                        const y = parseInt(parts[0], 10);
                        const m = parseInt(parts[1], 10) - 1;
                        const d = parseInt(parts[2], 10);
                        let hr = 0, mn = 0;
                        if (r.time) {
                            const tparts = r.time.split(":");
                            hr = parseInt(tparts[0], 10) || 0;
                            mn = parseInt(tparts[1], 10) || 0;
                        }
                        const candidate = new Date(y, m, d, hr, mn, 0);
                        if (candidate.getTime() > nowMs) return candidate.getTime();
                    }
                }
            }
            return fallbackDate.getTime();
        }

        const candidates = [
            { id: "doomsday",        ts: findReminderDate(["doomsday", "marvel"], new Date(2026, 11, 16, 0, 0, 0)) },
            { id: "friendly_spidey", ts: findReminderDate(["friendly", "neighborhood"], new Date(2027, 0, 13, 0, 0, 0)) },
            { id: "nsqk",            ts: findReminderDate(["nsqk", "mosca"], new Date(2027, 1, 27, 20, 0, 0)) },
            { id: "spiderverse",     ts: findReminderDate(["spider-verse", "spiderverse", "beyond"], new Date(2027, 5, 18, 0, 0, 0)) }
        ];

        let bestId = "doomsday";
        let bestDiff = Infinity;
        for (let i = 0; i < candidates.length; i++) {
            const diff = candidates[i].ts - nowMs;
            if (diff > 0 && diff < bestDiff) {
                bestDiff = diff;
                bestId = candidates[i].id;
            }
        }
        return bestId;
    }

    readonly property string userName: Quickshell.env("USER") || "ferram"
}
