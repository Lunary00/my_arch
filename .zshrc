## bindssd 
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char
bindkey "^H" backward-kill-word
bindkey "^[[3;5~" kill-word
bindkey "^[[1;5D" backward-word
##bindkey "^[[1;5C" forward-word Plugins

## Plugins
source  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# Fzf
source <(fzf --zsh)
# Habilita os bindings
source /usr/share/fzf/key-bindings.zsh
# Habilita autocompletar
source /usr/share/fzf/completion.zsh

# Starship Prompt
eval "$(starship init zsh)"


# Alias
alias ls='eza'
alias cat='bat'
alias service='htop'
alias blue='bluetui'
alias up='sudo pacman -Syu'
alias clean='sudo pacman -Rns $(pacman -Qtdq) 2>/dev/null; paccache -r; sudo journalctl --vacuum-time=30d; rm -rf ~/.cache/*'
alias rpi-imager='sudo -E QT_QPA_PLATFORM=wayland rpi-imager'
alias tmuxa='tmux attach || tmux new -s dev'
alias df='duf'

# add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"
