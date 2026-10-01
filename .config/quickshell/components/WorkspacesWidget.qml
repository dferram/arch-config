import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Item {
    id: root

    Theme { id: theme }

    implicitHeight: 28
    implicitWidth: dockFrame.implicitWidth
    height: 28
    width: implicitWidth

    // Target screen passed from shell.qml
    property var targetScreen: null

    // Monitor name (e.g. "eDP-1" or "HDMI-A-1")
    property string screenName: {
        if (targetScreen && targetScreen.name) return targetScreen.name;
        return "";
    }

    // Determine if this screen is the primary laptop display
    property bool isPrimaryScreen: {
        if (screenName !== "") {
            return screenName.indexOf("eDP") !== -1;
        }
        return true;
    }

    // Query Hyprland monitor for this screen
    property var hyprMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    property var monitorActiveWorkspace: hyprMonitor ? hyprMonitor.activeWorkspace : null
    property bool isMonitorFocused: hyprMonitor ? hyprMonitor.focused : false

    // Map of workspace client info: { [wsId]: { count, icon, appClass, title, summary } }
    property var workspaceInfo: ({})

    // Dynamic model of workspaces:
    // Workspaces 1-5 are always present on primary screen (6-10 on secondary).
    // In addition, any workspace > 5 with open windows or currently active dynamically appears!
    property var workspacesModel: {
        let base = isPrimaryScreen ? [1, 2, 3, 4, 5] : [6, 7, 8, 9, 10];
        let set = new Set(base);

        // Include any workspace that has open windows/clients
        for (let wsKey in root.workspaceInfo) {
            let id = parseInt(wsKey);
            if (!isNaN(id) && id > 0) {
                let info = root.workspaceInfo[wsKey];
                if (info && info.count > 0) {
                    set.add(id);
                }
            }
        }

        // Include active workspace on this monitor if set
        if (monitorActiveWorkspace && monitorActiveWorkspace.id !== undefined && monitorActiveWorkspace.id > 0) {
            set.add(monitorActiveWorkspace.id);
        }

        // Include focused workspace from Hyprland if valid
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id !== undefined && Hyprland.focusedWorkspace.id > 0) {
            set.add(Hyprland.focusedWorkspace.id);
        }

        let list = Array.from(set);
        list.sort((a, b) => a - b);
        return list;
    }

    // Active workspace ID on this monitor
    property int activeWorkspaceId: {
        if (monitorActiveWorkspace && monitorActiveWorkspace.id !== undefined && monitorActiveWorkspace.id > 0) {
            return monitorActiveWorkspace.id;
        }
        if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id !== undefined && Hyprland.focusedWorkspace.id > 0) {
            return Hyprland.focusedWorkspace.id;
        }
        return isPrimaryScreen ? 1 : 6;
    }

    // Process to switch workspace reliably in Hyprland (supporting Lua syntax)
    Process {
        id: switchProc
    }

    function switchToWorkspace(id) {
        if (!id || id <= 0) return;
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        switchProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"];
        switchProc.running = true;
    }

    function scrollWorkspace(delta) {
        let dir = delta > 0 ? "e-1" : "e+1";
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + dir + "\" })");
        switchProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + dir + "\" })"];
        switchProc.running = true;
    }

    // Official Spotify SVG
    property string spotifySvgUri: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='none'><g transform='translate(12, 12) scale(0.78) translate(-12, -12)'><path fill-rule='evenodd' clip-rule='evenodd' d='M12 0C5.373 0 0 5.373 0 12s5.373 12 12 12 12-5.373 12-12S18.627 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z' fill='%231ed760'/></g></svg>"

    // Official GitHub Octocat SVG (Pure White vector, transparent background)
    property string githubSvgUri: "file:///home/ferram/.local/share/icons/github.svg"

    // Official Git SVG
    property string gitSvgUri: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24' fill='%23F05032'><path d='M13.09 23.549a1.54 1.54 0 0 1-2.18 0L.451 13.089a1.54 1.54 0 0 1 0-2.179l7.191-7.19 2.733 2.733a1.85 1.85 0 0 0 .964 2.326v6.66a1.849 1.849 0 1 0 1.54 0V8.957l2.508 2.508a1.85 1.85 0 1 0 1.09-1.09l-2.634-2.634a1.85 1.85 0 0 0-2.378-2.377L8.73 2.63 10.91.451a1.54 1.54 0 0 1 2.179 0l10.459 10.46a1.54 1.54 0 0 1 0 2.179z'/></svg>"

    // Official Node.js SVG
    property string nodeSvgUri: "file:///home/ferram/.local/share/icons/node.svg"

    // Official Swagger API SVG
    property string swaggerSvgUri: "file:///home/ferram/.local/share/icons/swagger.svg"

    // Official Colgate-Palmolive 8-bit SVG
    property string cpSvgUri: "file:///home/ferram/.local/share/icons/cp.svg"

    // Official Troyanos UAQ SVG
    property string troyanosSvgUri: "file:///home/ferram/.local/share/icons/troyanos.svg"

    // Official Kitty Terminal SVG
    property string kittySvgUri: "file:///home/ferram/.local/share/icons/kitty.svg"

    // Rules to dynamically detect active browser tabs by window title
    property var webTabRules: [
        { keywords: ["colgate", "colpal"], icon: root.cpSvgUri },
        { keywords: ["troyanos", "uaq"], icon: root.troyanosSvgUri },
        { keywords: ["swagger", "swagger-ui", "api-docs", "/docs", "openapi"], icon: root.swaggerSvgUri },
        { keywords: ["youtube", "youtu.be", "music.youtube"], icon: "file:///home/ferram/.local/share/icons/youtube.svg" },
        { keywords: ["whatsapp", "web.whatsapp"], icon: "file:///home/ferram/.local/share/icons/whatsapp.svg" },
        { keywords: ["instagram"], icon: "file:///home/ferram/.local/share/icons/instagram.svg" },
        { keywords: ["chatgpt", "openai"], icon: "file:///home/ferram/.local/share/icons/chatgpt.svg" },
        { keywords: ["codex", "codex.openai"], icon: "file:///home/ferram/.local/share/icons/codex.svg" },
        { keywords: ["claude", "anthropic"], icon: "file:///home/ferram/.local/share/icons/claude.svg" },
        { keywords: ["gemini", "bard.google"], icon: "file:///home/ferram/.local/share/icons/gemini.svg" },
        { keywords: ["github"], icon: root.githubSvgUri },
        { keywords: ["spotify"], icon: root.spotifySvgUri },
        { keywords: ["pgadmin", "postgresql", "postgres", "psql", "5050", "localhost:5050", "localhost:5432", "5432", "dbeaver", "datagrip", "postico", "tableplus"], icon: "file:///home/ferram/.local/share/icons/postgresql.svg" },
        { keywords: ["docker", "lazydocker", "portainer", "hub.docker"], icon: "file:///home/ferram/.local/share/icons/docker.svg" },
        { keywords: ["linkedin", "linked in"], icon: "file:///home/ferram/.local/share/icons/linkedin.svg" },
        { keywords: ["leetcode"], icon: "file:///home/ferram/.local/share/icons/leetcode.svg" },
        { keywords: ["reddit"], icon: "file:///home/ferram/.local/share/icons/reddit.svg" },
        { keywords: ["twitter", "x.com", " x - "], icon: "file:///home/ferram/.local/share/icons/x.svg" },
        { keywords: ["twitch"], icon: "file:///home/ferram/.local/share/icons/twitch.svg" },
        { keywords: ["netflix"], icon: "file:///home/ferram/.local/share/icons/netflix.svg" },
        { keywords: ["notion"], icon: "file:///home/ferram/.local/share/icons/notion.svg" },
        { keywords: ["discord"], icon: "file:///home/ferram/.local/share/icons/discord.svg" },
        { keywords: ["telegram", "web.telegram"], icon: "file:///home/ferram/.local/share/icons/telegram.svg" },
        { keywords: ["soundcloud"], icon: "file:///home/ferram/.local/share/icons/soundcloud.svg" },
        { keywords: ["gmail", "mail.google"], icon: "file:///home/ferram/.local/share/icons/gmail.svg" },
        { keywords: ["classroom", "google classroom"], icon: "file:///home/ferram/.local/share/icons/classroom.svg" },
        { keywords: ["google docs", "docs.google", "documentos de google", "documento de google"], icon: "file:///home/ferram/.local/share/icons/docs.svg" },
        { keywords: ["google sheets", "sheets.google", "hojas de cálculo de google", "hoja de cálculo de google", "hojas de calculo"], icon: "file:///home/ferram/.local/share/icons/sheets.svg" },
        { keywords: ["google slides", "slides.google", "presentaciones de google", "presentación de google", "presentacion de google"], icon: "file:///home/ferram/.local/share/icons/slides.svg" },
        { keywords: ["google drive", "drive.google", "mi unidad", "my drive"], icon: "file:///home/ferram/.local/share/icons/drive.svg" },
        { keywords: ["google meet", "meet.google", "meet - "], icon: "file:///home/ferram/.local/share/icons/meet.svg" },
        { keywords: ["google calendar", "calendar.google", "calendario de google"], icon: "file:///home/ferram/.local/share/icons/calendar.svg" },
        { keywords: ["google forms", "forms.google", "formularios de google", "formulario de google"], icon: "file:///home/ferram/.local/share/icons/forms.svg" },
        { keywords: ["google keep", "keep.google"], icon: "file:///home/ferram/.local/share/icons/keep.svg" },
        { keywords: ["google search", "búsqueda de google", "busqueda de google", "google"], icon: "file:///home/ferram/.local/share/icons/google.svg" },
        { keywords: ["chrome://", "about:blank", "new tab - chromium", "nueva pestaña"], icon: "file:///home/ferram/.local/share/icons/chromium.svg" }
    ]

    function resolveWebTabIcon(titleLower) {
        if (!titleLower) return "";
        for (let i = 0; i < root.webTabRules.length; i++) {
            let rule = root.webTabRules[i];
            for (let k = 0; k < rule.keywords.length; k++) {
                if (titleLower.indexOf(rule.keywords[k]) !== -1) {
                    return rule.icon;
                }
            }
        }
        return "";
    }

    function resolveClientInfo(client) {
        if (!client) return { icon: "", isTerminal: false, isAi: false };
        let cls = client.class || client.initialClass || "";
        if (!cls) return { icon: "", isTerminal: false, isAi: false };

        let lower = cls.toLowerCase();
        let title = client.title || "";
        let titleLower = title.toLowerCase();
        let proc = (client.processName || "").toLowerCase();

        let isTerm = (lower.indexOf("kitty") !== -1 || lower.indexOf("terminal") !== -1 || 
                      lower.indexOf("alacritty") !== -1 || lower.indexOf("foot") !== -1 || 
                      lower.indexOf("wezterm") !== -1 || lower.indexOf("xterm") !== -1);

        // --- 1. Terminal windows: Smart AI & CLI tool detection ---
        if (isTerm) {
            // A. AI Tools in Terminal
            // Devin uses task titles, so prefer the detected CLI process.
            if (proc === "devin" || proc === "devin-cli" ||
                (!proc && /^devin(?:\s|$)/.test(titleLower))) {
                return {
                    icon: "file:///usr/share/pixmaps/devin-desktop.png",
                    isTerminal: true,
                    isAi: true
                };
            }
            // Antigravity CLI (agy / antigravity)
            if (proc.indexOf("agy") !== -1 || proc.indexOf("antigravity") !== -1 ||
                titleLower === "agy" || titleLower.startsWith("agy ") || titleLower.indexOf(" agy") !== -1 || titleLower.indexOf("antigravity") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/antigravity.png",
                    isTerminal: true,
                    isAi: true
                };
            }
            // Google Gemini CLI
            if (proc.indexOf("gemini") !== -1 || proc.indexOf("bard") !== -1 ||
                titleLower.indexOf("gemini") !== -1 || titleLower.indexOf("bard") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/gemini.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // Anthropic Claude / Claude Code
            if (proc.indexOf("claude") !== -1 || proc.indexOf("anthropic") !== -1 ||
                titleLower.indexOf("claude") !== -1 || titleLower.indexOf("anthropic") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/claude.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // ChatGPT / sgpt / OpenAI
            if (proc.indexOf("chatgpt") !== -1 || proc.indexOf("sgpt") !== -1 ||
                titleLower.indexOf("chatgpt") !== -1 || titleLower.indexOf("openai") !== -1 || 
                titleLower.indexOf("sgpt") !== -1 || titleLower === "gpt" || titleLower.startsWith("gpt ")) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/chatgpt.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // OpenAI Codex CLI
            if (proc.indexOf("codex") !== -1 || proc.indexOf("openai-codex") !== -1 ||
                titleLower === "codex" || titleLower.startsWith("codex ") || titleLower.indexOf(" codex") !== -1 || titleLower.indexOf("openai-codex") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/codex.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // Ollama
            if (proc.indexOf("ollama") !== -1 || titleLower.indexOf("ollama") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/ollama.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // GitHub Copilot CLI
            if (proc.indexOf("copilot") !== -1 || titleLower.indexOf("copilot") !== -1 || titleLower.indexOf("gh copilot") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/copilot.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // DeepSeek CLI
            if (proc.indexOf("deepseek") !== -1 || titleLower.indexOf("deepseek") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/deepseek.svg",
                    isTerminal: true,
                    isAi: true
                };
            }
            // Aider / Open-Interpreter / LLM CLI
            if (proc.indexOf("aider") !== -1 || proc.indexOf("interpreter") !== -1 || proc.indexOf("llm") !== -1 ||
                titleLower.indexOf("aider") !== -1 || titleLower.indexOf("interpreter") !== -1 || 
                titleLower.indexOf("llm") !== -1 || titleLower.indexOf("fabric") !== -1 || titleLower.indexOf("mods") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/gemini.svg",
                    isTerminal: true,
                    isAi: true
                };
            }

            // B. Other CLI developer tools in Terminal
            // Colgate-Palmolive context / repo in Terminal
            if (proc.indexOf("colgate") !== -1 || proc.indexOf("colpal") !== -1 ||
                titleLower.indexOf("colgate") !== -1 || titleLower.indexOf("colpal") !== -1 ||
                !!client.isColgate) {
                return {
                    icon: root.cpSvgUri,
                    isTerminal: true,
                    isAi: false
                };
            }
            // Troyanos UAQ context / repo in Terminal
            if (proc.indexOf("troyanos") !== -1 || proc.indexOf("uaq") !== -1 ||
                titleLower.indexOf("troyanos") !== -1 || titleLower.indexOf("uaq") !== -1) {
                return {
                    icon: root.troyanosSvgUri,
                    isTerminal: true,
                    isAi: false
                };
            }
            // Docker & Container tools
            if (proc.indexOf("docker") !== -1 || proc.indexOf("lazydocker") !== -1 || proc.indexOf("podman") !== -1 ||
                titleLower.indexOf("docker") !== -1 || titleLower.indexOf("lazydocker") !== -1 || 
                titleLower.indexOf("podman") !== -1 || titleLower.indexOf("container") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/docker.svg",
                    isTerminal: true,
                    isAi: false
                };
            }
            // Lazygit / Git
            if (proc.indexOf("lazygit") !== -1 || proc.indexOf("git") !== -1 ||
                titleLower.indexOf("lazygit") !== -1 || titleLower.startsWith("git ") || titleLower.indexOf(" git") !== -1 ||
                !!client.isGitRepo) {
                return {
                    icon: root.gitSvgUri,
                    isTerminal: true,
                    isAi: false
                };
            }
            // GitHub CLI in Terminal
            if (proc === "gh" || proc.startsWith("gh ") || titleLower.startsWith("gh ")) {
                return {
                    icon: root.githubSvgUri,
                    isTerminal: true,
                    isAi: false
                };
            }
            // Node.js server / dev process
            if (proc.indexOf("node") !== -1 || proc.indexOf("nodemon") !== -1 || proc.indexOf("npm") !== -1 ||
                proc.indexOf("npx") !== -1 || proc.indexOf("vite") !== -1 || proc.indexOf("next") !== -1 ||
                proc.indexOf("pnpm") !== -1 || proc.indexOf("bun") !== -1 ||
                titleLower.indexOf("node ") !== -1 || titleLower.startsWith("node ") ||
                titleLower.indexOf("npm ") !== -1 || titleLower.startsWith("npm ") ||
                titleLower.indexOf("nodemon") !== -1 || titleLower.indexOf("vite") !== -1) {
                return {
                    icon: root.nodeSvgUri,
                    isTerminal: true,
                    isAi: false
                };
            }
            // Neovim / Vim
            if (proc.indexOf("nvim") !== -1 || proc.indexOf("neovim") !== -1 || proc.indexOf("vim") !== -1 ||
                titleLower.indexOf("nvim") !== -1 || titleLower.indexOf("neovim") !== -1 || titleLower.indexOf("vim") !== -1) {
                let nvimIcon = Quickshell.iconPath("nvim", true) || Quickshell.iconPath("neovim", true) || Quickshell.iconPath("code", true);
                return {
                    icon: nvimIcon,
                    isTerminal: true,
                    isAi: false
                };
            }
            // System Monitors (btop, htop, nvtop)
            if (proc.indexOf("btop") !== -1 || proc.indexOf("htop") !== -1 || proc.indexOf("nvtop") !== -1 ||
                titleLower.indexOf("btop") !== -1 || titleLower.indexOf("htop") !== -1 || titleLower.indexOf("nvtop") !== -1) {
                let btopIcon = Quickshell.iconPath("btop", true) || Quickshell.iconPath("utilities-system-monitor", true);
                return {
                    icon: btopIcon,
                    isTerminal: true,
                    isAi: false
                };
            }
            // Audio visualizer: cava
            if (proc.indexOf("cava") !== -1 || titleLower.indexOf("cava") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/soundcloud.svg",
                    isTerminal: true,
                    isAi: false
                };
            }
            // PostgreSQL CLI: psql
            if (proc.indexOf("psql") !== -1 || proc.indexOf("postgres") !== -1 ||
                titleLower.indexOf("psql") !== -1 || titleLower.indexOf("postgres") !== -1) {
                return {
                    icon: "file:///home/ferram/.local/share/icons/postgresql.svg",
                    isTerminal: true,
                    isAi: false
                };
            }

            // Standard terminal (bash, zsh, kitty, etc.): show clean Kitty icon without sub-badge
            return {
                icon: root.kittySvgUri,
                isTerminal: false,
                isAi: false
            };
        }

        // --- 2. GUI Applications ---
        // Antigravity IDE (GUI)
        if (lower.indexOf("antigravity") !== -1) {
            let agIcon = "file:///home/ferram/.local/share/icons/antigravity.png";
            return { icon: agIcon, isTerminal: false, isAi: true };
        }

        // OpenAI Codex
        if (lower.indexOf("codex") !== -1 || titleLower.indexOf("codex") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/codex.svg", isTerminal: false, isAi: true };
        }

        // Docker Desktop / GUI
        if (lower.indexOf("docker") !== -1 || lower.indexOf("lazydocker") !== -1 || lower.indexOf("podman") !== -1 ||
            titleLower.indexOf("docker") !== -1 || titleLower.indexOf("lazydocker") !== -1 || titleLower.indexOf("podman") !== -1 ||
            titleLower.indexOf("container") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/docker.svg", isTerminal: false, isAi: false };
        }

        // PostgreSQL & pgAdmin
        if (lower.indexOf("pgadmin") !== -1 || lower.indexOf("postgres") !== -1 || lower.indexOf("psql") !== -1 ||
            lower.indexOf("dbeaver") !== -1 || lower.indexOf("datagrip") !== -1 ||
            titleLower.indexOf("pgadmin") !== -1 || titleLower.indexOf("postgres") !== -1 || titleLower.indexOf("psql") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/postgresql.svg", isTerminal: false, isAi: false };
        }

        // LinkedIn
        if (lower.indexOf("linkedin") !== -1 || titleLower.indexOf("linkedin") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/linkedin.svg", isTerminal: false, isAi: false };
        }

        // Spotify
        if (lower.indexOf("spotify") !== -1) {
            return { icon: root.spotifySvgUri, isTerminal: false, isAi: false };
        }

        // GitHub
        if (lower.indexOf("github") !== -1 || titleLower.indexOf("github") !== -1) {
            return { icon: root.githubSvgUri, isTerminal: false, isAi: false };
        }

        // Git GUI / Git tools
        if (lower.indexOf("git") !== -1 || titleLower.indexOf("git") !== -1) {
            return { icon: root.gitSvgUri, isTerminal: false, isAi: false };
        }

        // Swagger API
        if (lower.indexOf("swagger") !== -1 || titleLower.indexOf("swagger") !== -1 || titleLower.indexOf("api-docs") !== -1) {
            return { icon: root.swaggerSvgUri, isTerminal: false, isAi: false };
        }

        // Chrome PWA / App Mode
        if (lower.startsWith("chrome-")) {
            let pwaIcon = Quickshell.iconPath(cls, true);
            if (pwaIcon) return { icon: pwaIcon, isTerminal: false, isAi: false };
            let tabIcon = root.resolveWebTabIcon(titleLower);
            if (tabIcon) return { icon: tabIcon, isTerminal: false, isAi: false };
        }

        // Web browser windows: tab detection
        if (lower.indexOf("chromium") !== -1 || lower.indexOf("chrome") !== -1 || lower.indexOf("brave") !== -1) {
            let tabIcon = root.resolveWebTabIcon(titleLower);
            if (tabIcon) return { icon: tabIcon, isTerminal: false, isAi: false };
            return { icon: "file:///home/ferram/.local/share/icons/chromium.svg", isTerminal: false, isAi: false };
        }

        // Known desktop applications
        if (lower.indexOf("whatsapp") !== -1 || titleLower.indexOf("whatsapp") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/whatsapp.svg", isTerminal: false, isAi: false };
        }
        if (lower.indexOf("instagram") !== -1 || titleLower.indexOf("instagram") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/instagram.svg", isTerminal: false, isAi: false };
        }
        if (lower.indexOf("hypr") !== -1 || lower.indexOf("arch") !== -1) {
            return { icon: "file:///home/ferram/.local/share/icons/arch.svg", isTerminal: false, isAi: false };
        }
        if (lower.indexOf("code") !== -1 || lower.indexOf("vscode") !== -1) {
            return { icon: Quickshell.iconPath("code", true) || Quickshell.iconPath("visual-studio-code", true), isTerminal: false, isAi: false };
        }
        if (lower.indexOf("dolphin") !== -1) {
            return { icon: Quickshell.iconPath("org.kde.dolphin", true) || Quickshell.iconPath("system-file-manager", true), isTerminal: false, isAi: false };
        }
        if (lower.indexOf("devin") !== -1) {
            return { icon: Quickshell.iconPath("devin-desktop", true), isTerminal: false, isAi: true };
        }
        if (lower.indexOf("thunar") !== -1 || lower.indexOf("nautilus") !== -1 || lower.indexOf("file") !== -1) {
            return { icon: Quickshell.iconPath("system-file-manager", true), isTerminal: false, isAi: false };
        }
        if (lower.indexOf("easyeffects") !== -1) {
            return { icon: Quickshell.iconPath("com.github.wwmm.easyeffects", true), isTerminal: false, isAi: false };
        }
        if (lower.indexOf("pavucontrol") !== -1) {
            return { icon: Quickshell.iconPath("multimedia-volume-control", true), isTerminal: false, isAi: false };
        }

        // Direct match with Quickshell.iconPath
        let icon = Quickshell.iconPath(cls, true) || Quickshell.iconPath(lower, true);
        if (icon) return { icon: icon, isTerminal: false, isAi: false };

        return { icon: "file:///home/ferram/.local/share/icons/arch.svg", isTerminal: false, isAi: false };
    }

    function resolveAppIcon(client) {
        return resolveClientInfo(client).icon;
    }

    function updateClientsData(clientsList) {
        if (!clientsList || !Array.isArray(clientsList)) return;

        let map = {};
        for (let i = 0; i < clientsList.length; i++) {
            let c = clientsList[i];
            let wsId = (c.workspace && c.workspace.id !== undefined) ? c.workspace.id : null;
            if (wsId === null || wsId === undefined || wsId <= 0) continue;

            let sz = c.size || [0, 0];
            let area = (sz[0] || 0) * (sz[1] || 0);

            if (!map[wsId]) {
                map[wsId] = {
                    count: 0,
                    lowestFocusId: 999999,
                    activeClient: null,
                    largestArea: -1,
                    largestClient: null,
                    titles: []
                };
            }

            map[wsId].count += 1;
            if (c.title) map[wsId].titles.push(c.title);

            let fId = (c.focusHistoryID !== undefined && c.focusHistoryID !== null) ? c.focusHistoryID : 99999;
            if (fId < map[wsId].lowestFocusId) {
                map[wsId].lowestFocusId = fId;
                map[wsId].activeClient = c;
            }

            // Keep the client occupying the most screen space
            if (area > map[wsId].largestArea) {
                map[wsId].largestArea = area;
                map[wsId].largestClient = c;
            }
        }

        let newInfo = {};
        for (let wsKey in map) {
            let item = map[wsKey];
            let client = item.activeClient || item.largestClient;
            let meta = resolveClientInfo(client);
            newInfo[wsKey] = {
                count: item.count,
                icon: meta.icon,
                isTerminal: meta.isTerminal,
                isAi: meta.isAi,
                appClass: client ? (client.class || client.initialClass || "") : "",
                title: client ? (client.title || "") : "",
                summary: item.titles.join(", ")
            };
        }
        root.workspaceInfo = newInfo;
    }

    function refreshClients() {
        if (!clientsProc.running) {
            clientsProc.running = true;
        }
    }

    Process {
        id: clientsProc
        command: ["/home/ferram/.local/bin/hypr-clients"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                let txt = text.trim();
                if (!txt) return;
                try {
                    let data = JSON.parse(txt);
                    root.updateClientsData(data);
                } catch(e) {
                    // Ignore transient parsing issues
                }
            }
        }
    }

    // React in real time to Hyprland window and workspace events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            let name = event.name;
            if (name === "openwindow" || name === "closewindow" || name === "movewindow" ||
                name === "movewindowv2" || name === "changefloatingmode" || name === "fullscreen" ||
                name === "activewindow" || name === "activewindowv2" || name === "workspace" ||
                name === "focusedmon") {
                root.refreshClients();
            }
        }
    }

    // Periodic safety check
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refreshClients()
    }

    // Unified Frosted Glass Workspaces Island
    Rectangle {
        id: dockFrame
        height: 28
        implicitWidth: wsRow.implicitWidth + 8
        anchors.verticalCenter: parent.verticalCenter
        radius: theme.radiusSmall
        color: Qt.rgba(255, 255, 255, 0.04)
        border.color: theme.borderSubtle
        border.width: 1

        WheelHandler {
            onWheel: (event) => {
                root.scrollWorkspace(event.angleDelta.y);
            }
        }

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 4
            z: 1

            Repeater {
                model: root.workspacesModel

                Rectangle {
                    id: wsPill
                    property int wsId: modelData
                    property bool isCurrent: root.activeWorkspaceId === wsId
                    property bool isFocused: isCurrent && (root.isMonitorFocused || (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId))

                    property var wsData: root.workspaceInfo[wsId] || null
                    property bool hasClients: wsData !== null && wsData.count > 0
                    property string iconSource: hasClients ? (wsData.icon || "") : ""
                    property bool isTerminalClient: hasClients && !!wsData.isTerminal
                    property bool isAiClient: hasClients && !!wsData.isAi
                    property int clientCount: hasClients ? wsData.count : 0
                    property bool imageError: false

                    // Dynamic width for fluid modern feel
                    width: isFocused ? 38 : (isCurrent ? 34 : (hasClients ? (isTerminalClient ? 32 : 30) : 26))
                    height: 24
                    radius: theme.radiusSmall - 2
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width {
                        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    }

                    // Frosted glass background: translucent obsidian with blue ambient glow
                    color: {
                        if (isFocused) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28);
                        if (isCurrent) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.16);
                        if (wsMouse.containsMouse) return Qt.rgba(255, 255, 255, 0.14);
                        if (hasClients) return Qt.rgba(255, 255, 255, 0.06);
                        return Qt.rgba(255, 255, 255, 0.02);
                    }

                    border.color: {
                        if (isFocused) return theme.blueLight;
                        if (isCurrent) return Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.55);
                        if (wsMouse.containsMouse) return Qt.rgba(255, 255, 255, 0.28);
                        return Qt.rgba(255, 255, 255, 0.08);
                    }
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }
                    Behavior on border.color { ColorAnimation { duration: 220; easing.type: Easing.OutQuad } }

                    scale: wsMouse.containsMouse ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                    // Luminous glowing bottom capsule indicator for active workspace
                    Rectangle {
                        id: activeIndicator
                        visible: wsPill.isCurrent
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1.5
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: wsPill.isFocused ? 14 : 7
                        height: 2
                        radius: 1
                        color: wsPill.isFocused ? theme.blueLight : theme.blue

                        Behavior on width {
                            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                        }
                    }

                    // 1. App Icon (shown when there are clients and icon loaded successfully)
                    Image {
                        id: appIconImg
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: wsPill.isCurrent ? -1 : 0
                        width: 20
                        height: 16
                        source: wsPill.iconSource
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: false
                        visible: wsPill.hasClients && wsPill.iconSource !== "" && !wsPill.imageError

                        scale: wsPill.isFocused ? 1.08 : (wsMouse.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                        onStatusChanged: {
                            if (status === Image.Error) {
                                wsPill.imageError = true;
                            } else if (status === Image.Ready) {
                                wsPill.imageError = false;
                            }
                        }
                    }

                    // 2. Workspace Number / Minimal indicator (shown when no icon available)
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: wsPill.isCurrent ? -0.5 : 0.5
                        text: wsPill.wsId
                        visible: !appIconImg.visible
                        color: {
                            if (wsPill.isFocused) return "#ffffff";
                            if (wsPill.isCurrent) return theme.blueLight;
                            if (wsMouse.containsMouse) return theme.text;
                            if (wsPill.hasClients) return theme.textSub;
                            return Qt.rgba(theme.textMuted.r, theme.textMuted.g, theme.textMuted.b, 0.6);
                        }
                        font.family: theme.fontFamily
                        font.pixelSize: wsPill.isCurrent ? 11 : 10
                        font.weight: wsPill.isCurrent ? Font.Bold : (wsPill.hasClients ? Font.DemiBold : Font.Normal)
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter

                        scale: wsPill.isFocused ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }

                    // 3. Multi-window Badge (shows client count when more than 1 window is open)
                    Rectangle {
                        visible: wsPill.clientCount > 1
                        scale: wsPill.clientCount > 1 ? 1.0 : 0.0
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 0.5
                        anchors.rightMargin: 0.5
                        width: 9
                        height: 9
                        radius: 4.5
                        color: wsPill.isFocused ? theme.blueLight : theme.blue
                        border.color: theme.bgDark
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: wsPill.clientCount
                            color: wsPill.isFocused ? theme.bgDark : "#ffffff"
                            font.family: theme.fontFamily
                            font.pixelSize: 7
                            font.weight: Font.Bold
                        }
                    }

                    // 4. Terminal Sub-badge (shows CLI prompt >_ for apps/AIs running inside terminal)
                    Rectangle {
                        id: termBadge
                        visible: wsPill.isTerminalClient
                        scale: wsPill.isTerminalClient ? 1.0 : 0.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.bottomMargin: 1
                        anchors.leftMargin: 1
                        width: 10
                        height: 8
                        radius: 2
                        color: "#0a0c14"
                        border.color: wsPill.isAiClient ? theme.blueLight : Qt.rgba(255, 255, 255, 0.40)
                        border.width: 1
                        z: 3

                        Text {
                            anchors.centerIn: parent
                            text: ">_"
                            color: wsPill.isAiClient ? theme.blueLight : "#e2e8f0"
                            font.family: "monospace"
                            font.pixelSize: 6
                            font.weight: Font.Bold
                        }
                    }

                    // Workspace indicator (visual only; switching is strictly via keyboard shortcuts)
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.ArrowCursor
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }
}
