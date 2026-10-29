# dev_env zsh: options, history, PATH

# history
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# navigation / editing
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
setopt PROMPT_SUBST
setopt EXTENDED_GLOB

# PATH: keep ~/.local/bin first and avoid duplicates
typeset -U path
path=("$HOME/.local/bin" $path)
export PATH

# editor default; do not override an existing choice
if (( $+commands[nvim] )); then
  : ${EDITOR:=nvim}
  : ${VISUAL:=$EDITOR}
  export EDITOR VISUAL
fi

# history navigation
bindkey '^[[A' up-line-or-history
bindkey '^[[B' down-line-or-history
bindkey '^R' history-incremental-search-backward

# word navigation
# iTerm2 with "Option Key Sends: Normal" sends CSI 1;3D / CSI 1;3C.
# Ctrl+Left/Right uses CSI 1;5D / CSI 1;5C; Esc+b/f covers terminals
# configured to send Meta/Esc sequences.
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[b' backward-word
bindkey '^[f' forward-word
