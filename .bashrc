#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- Bash Line Editor (Visual Suggestions & Color) ---
source ~/.local/share/blesh/ble.sh

# --- Command Aliases ---
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias tree='eza --tree --icons --level=2'
else
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -la --color=auto --group-directories-first'
fi

if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
fi

alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

# --- Zoxide Integration (Smart cd) ---
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi

# --- FZF Integration (Interactive Search Ctrl+R / Ctrl+T) ---
if command -v fzf &>/dev/null; then
    eval "$(fzf --bash 2>/dev/null)"
    export FZF_DEFAULT_OPTS="--height 45% --layout=reverse --border \
--color=bg+:#18181b,bg:#0a0a0d,spinner:#ff787d,hl:#ff787d,fg:#e4e4e7,header:#71717a,info:#ff787d,pointer:#e22b31,marker:#e22b31,fg+:#ffffff,prompt:#e22b31,hl+:#ff787d"

    # Rich preview with bat on Ctrl+T
    if command -v bat &>/dev/null; then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || cat {} 2>/dev/null' --preview-window=right:55%:wrap"
    fi
fi

# --- Prompt (Starship) ---
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# Added by Antigravity CLI installer
export PATH="/home/ferram/.local/bin:$PATH"

# Fullstack Developer & Diagnostic Shortcuts
alias lr="laptop-report"
alias ld="lazydocker"
alias d="dust"
alias kp="killport"
alias db="dev-db"

# --- Fast Directory Navigation ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# --- Interactive Wayland Clipboard ---
alias clip="wl-copy"
alias paste="wl-paste"

# --- System Resource Monitor ---
if command -v btop &>/dev/null; then
    alias top="btop"
    alias htop="btop"
fi

# --- Quick Environment Reload ---
alias reload="source ~/.bashrc && echo 'Bash configuration reloaded.'"

# --- Mouse-free Interactive Fuzzy Finders (FZF) ---
# Jump instantly to any project
p() {
    local target
    target=$(fd -t d -d 1 . ~/Personal ~/Projects ~/Colgate-Palmolive 2>/dev/null | fzf --height 40% --reverse --prompt="Project > ")
    [ -n "$target" ] && cd "$target"
}

# Open file interactively in terminal editor (nvim)
v() {
    local target
    if [ $# -gt 0 ]; then
        ${EDITOR:-nvim} "$@"
    else
        target=$(fzf --preview 'bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || cat {} 2>/dev/null')
        [ -n "$target" ] && ${EDITOR:-nvim} "$target"
    fi
}

# Open file interactively in Antigravity IDE
vc() {
    local target
    if [ $# -gt 0 ]; then
        code "$@"
    else
        target=$(fzf --preview 'bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || cat {} 2>/dev/null')
        [ -n "$target" ] && code "$target"
    fi
}

# Search text inside files with ripgrep + fzf and jump to exact line
rgf() {
    local match
    match=$(rg --column --line-number --no-heading --color=always --smart-case "${*:-}" 2>/dev/null | \
        fzf --ansi \
            --delimiter : \
            --preview 'bat --color=always --style=numbers,changes --highlight-line {2} {1} 2>/dev/null' \
            --preview-window 'right:60%:+{2}-5' \
            --prompt="Code search > ")

    if [ -n "$match" ]; then
        local file=$(echo "$match" | cut -d: -f1)
        local line=$(echo "$match" | cut -d: -f2)
        ${EDITOR:-nvim} "+$line" "$file"
    fi
}

# Interactively kill processes with fzf (TAB for multi-select, ENTER to kill)
fkill() {
    local pid
    pid=$(ps -f -u "$USER" | sed 1d | fzf -m --height 45% --reverse --prompt="Kill process > " --header='[fkill] TAB: multi-select | ENTER: kill process' | awk '{print $2}')
    if [ -n "$pid" ]; then
        echo "$pid" | xargs kill -${1:-9} 2>/dev/null && echo "Process(es) $pid terminated."
    fi
}

# Create directory and enter immediately
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract any archive without memorizing flags
extract() {
    if [ -f "$1" ]; then
        bsdtar -xf "$1"
    else
        echo "'$1' is not a valid file"
    fi
}

# --- Quick Access to Web & Localhost in Chromium ---
# Open localhost in Chromium (e.g., 'loc' for :3000, 'loc 5173', 'loc 8080')
loc() {
    local port="${1:-3000}"
    chromium "http://localhost:$port" &>/dev/null &
}

# Open URL or Google search from terminal
web() {
    if [ -z "$1" ]; then
        chromium &>/dev/null &
    elif [[ "$1" =~ ^https?:// ]] || [[ "$1" =~ ^localhost ]]; then
        chromium "$1" &>/dev/null &
    else
        chromium "https://www.google.com/search?q=$*" &>/dev/null &
    fi
}

# --- Autocompletion ---
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
