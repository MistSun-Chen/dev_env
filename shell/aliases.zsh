# dev_env zsh: aliases and small helpers

# ---------- listing ----------
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias ll='eza -lh --git --group-directories-first'
  alias la='eza -lah --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
elif (( $+commands[colorls] )); then
  alias ls='colorls --group-directories-first'
  alias ll='colorls -lA --sd --gs --group-directories-first'
  alias la='colorls -la --group-directories-first'
  alias lt='colorls --tree=2'
else
  if [[ "$OSTYPE" == darwin* ]]; then
    alias ls='ls -G'
  else
    alias ls='ls --color=auto'
  fi
  alias ll='ls -lh'
  alias la='ls -lah'
  alias lt='ls -lht'
fi

# ---------- editor ----------
if (( $+commands[nvim] )); then
  alias vim='nvim'
  alias vi='nvim'
  alias v='nvim'
fi

# ---------- git ----------
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gds='git diff --staged'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -20'
alias gst='git stash'
alias gstp='git stash pop'

# ---------- tmux ----------
if (( $+commands[tmux] )); then
  alias ta='tmux attach -t'
  alias ts='tmux new-session -s'
  alias tl='tmux list-sessions'
  alias td='tmux detach'
fi

# ---------- navigation ----------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias path='print -l $path'

mkcd() {
  if [[ $# -ne 1 ]]; then
    print -u2 'usage: mkcd <dir>'
    return 1
  fi
  mkdir -p -- "$1" && cd -- "$1"
}

reload() {
  source "${ZDOTDIR:-$HOME}/.zshrc"
}
