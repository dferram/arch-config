#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- Aliases para Comandos ---
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

# --- Integración de Zoxide (cd inteligente) ---
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi

# --- Integración de FZF (búsqueda interactiva Ctrl+R / Ctrl+T) ---
if command -v fzf &>/dev/null; then
    eval "$(fzf --bash 2>/dev/null)"
    export FZF_DEFAULT_OPTS="--height 45% --layout=reverse --border \
--color=bg+:#18181b,bg:#0a0a0d,spinner:#ff787d,hl:#ff787d,fg:#e4e4e7,header:#71717a,info:#ff787d,pointer:#e22b31,marker:#e22b31,fg+:#ffffff,prompt:#e22b31,hl+:#ff787d"

    # Vista previa enriquecida con bat en Ctrl+T
    if command -v bat &>/dev/null; then
        export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || cat {} 2>/dev/null' --preview-window=right:55%:wrap"
    fi
fi

# --- Prompt Armónico (Tema Oscuro + Acento Rojo #e22b31 / #ff787d) ---
set_bash_prompt() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local git_info=""
    if [ -n "$branch" ]; then
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            # Con cambios pendientes: rojo carmesí (#e22b31) con asterisco
            git_info=" \[\e[38;2;226;43;49m\e[1m\](${branch}*)\[\e[0m\]"
        else
            # Repositorio limpio: coral suave (#ff787d)
            git_info=" \[\e[38;2;255;150;155m\](${branch})\[\e[0m\]"
        fi
    fi
    # usuario@equipo en blanco hielo nítido (#f5f5f5), directorio en rojo vibrante (#ff6b6b), símbolo $ en rojo carmesí
    PS1="\[\e[38;2;245;245;245m\e[1m\]\u@\h\[\e[0m\e[38;2;100;100;100m\]:\[\e[38;2;255;107;107m\e[1m\]\w\[\e[0m\]${git_info} \[\e[38;2;226;43;49m\e[1m\]\$\[\e[0m\] "
}
PROMPT_COMMAND=set_bash_prompt

# Added by Antigravity CLI installer
export PATH="/home/ferram/.local/bin:$PATH"

# Fullstack Developer & Diagnostic Shortcuts
alias lr="laptop-report"
alias ld="lazydocker"
alias d="dust"
alias kp="killport"
alias db="dev-db"

# --- Navegación rápida de directorios ---
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# --- Portapapeles Wayland interactivo ---
alias clip="wl-copy"
alias paste="wl-paste"

# --- Monitor de recursos del sistema ---
if command -v btop &>/dev/null; then
    alias top="btop"
    alias htop="btop"
fi

# --- Recarga rápida de entorno ---
alias reload="source ~/.bashrc && echo 'Configuración de Bash recargada.'"

# --- Buscadores interactivos sin mouse (FZF) ---
# Saltar al instante a cualquier proyecto
p() {
    local target
    target=$(fd -t d -d 1 . ~/Personal ~/Projects ~/Colgate-Palmolive 2>/dev/null | fzf --height 40% --reverse --prompt="📂 Proyecto > ")
    [ -n "$target" ] && cd "$target"
}

# Abrir archivo interactivamente en editor de terminal (nvim)
v() {
    local target
    if [ $# -gt 0 ]; then
        ${EDITOR:-nvim} "$@"
    else
        target=$(fzf --preview 'bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || cat {} 2>/dev/null')
        [ -n "$target" ] && ${EDITOR:-nvim} "$target"
    fi
}

# Abrir archivo interactivamente en Antigravity IDE
vc() {
    local target
    if [ $# -gt 0 ]; then
        code "$@"
    else
        target=$(fzf --preview 'bat --color=always --style=numbers,changes --line-range :300 {} 2>/dev/null || cat {} 2>/dev/null')
        [ -n "$target" ] && code "$target"
    fi
}

# Buscar texto dentro de archivos con ripgrep + fzf y abrir en la línea exacta
rgf() {
    local match
    match=$(rg --column --line-number --no-heading --color=always --smart-case "${*:-}" 2>/dev/null | \
        fzf --ansi \
            --delimiter : \
            --preview 'bat --color=always --style=numbers,changes --highlight-line {2} {1} 2>/dev/null' \
            --preview-window 'right:60%:+{2}-5' \
            --prompt="🔎 Buscar en código > ")

    if [ -n "$match" ]; then
        local file=$(echo "$match" | cut -d: -f1)
        local line=$(echo "$match" | cut -d: -f2)
        ${EDITOR:-nvim} "+$line" "$file"
    fi
}

# Matar procesos de forma interactiva con fzf (TAB para multiselección, ENTER para matar)
fkill() {
    local pid
    pid=$(ps -f -u "$USER" | sed 1d | fzf -m --height 45% --reverse --prompt="☠️ Matar proceso > " --header='[fkill] TAB: multiselección | ENTER: matar proceso' | awk '{print $2}')
    if [ -n "$pid" ]; then
        echo "$pid" | xargs kill -${1:-9} 2>/dev/null && echo "Proceso(s) $pid finalizado(s)."
    fi
}

# Crear directorio y entrar de inmediato
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Descomprimir cualquier archivo sin recordar flags
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *.tar.xz)    tar xf "$1"      ;;
            *)           echo "No se reconoce el formato de compresión de '$1'" ;;
        esac
    else
        echo "'$1' no es un archivo válido"
    fi
}

# --- Acceso rápido a Web y Localhost en Chromium ---
# Abrir localhost en Chromium (ej: 'loc' para :3000, 'loc 5173', 'loc 8080')
loc() {
    local port="${1:-3000}"
    chromium "http://localhost:$port" &>/dev/null &
}

# Abrir URL o buscar en Google desde la terminal
web() {
    if [ -z "$1" ]; then
        chromium &>/dev/null &
    elif [[ "$1" =~ ^https?:// ]] || [[ "$1" =~ ^localhost ]]; then
        chromium "$1" &>/dev/null &
    else
        chromium "https://www.google.com/search?q=$*" &>/dev/null &
    fi
}





