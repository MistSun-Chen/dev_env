# dev_env zsh: optional pure-zsh plugins
# 这些插件不依赖 Zinit/Oh My Zsh；缺失时静默跳过。

if [[ -r "$DEV_ENV_SHELL_DIR/vendor/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  source "$DEV_ENV_SHELL_DIR/vendor/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-syntax-highlighting 必须在所有 widget/alias 定义之后加载；
# 实际 source 放在 zshrc 最后，这里只设置样式。
if [[ -r "$DEV_ENV_SHELL_DIR/vendor/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  typeset -gA ZSH_HIGHLIGHT_STYLES
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
  ZSH_HIGHLIGHT_STYLES[command]='fg=#a6e3a1'
  ZSH_HIGHLIGHT_STYLES[builtin]='fg=#89b4fa'
  ZSH_HIGHLIGHT_STYLES[alias]='fg=#cba6f7'
  ZSH_HIGHLIGHT_STYLES[path]='fg=#f9e2af'
  ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#f38ba8'
fi
