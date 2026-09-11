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


