# Source alias files
for f in ~/.zsh/aliases/*.sh(N); do
  source "$f"
done

# Machine-specific overrides (not tracked in dotfiles)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
