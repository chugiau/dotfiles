#!/bin/sh

DOTFILES="$HOME/.dotfiles"

# 自動找出所有 .symlink 檔案並建立連結
create_symlinks() {
  for src in $(find "$DOTFILES" -name "*.symlink"); do
    dst="$HOME/.$(basename "${src%.symlink}")"
    ln -sf "$src" "$dst"
  done
}

# 安裝 git hooks
install_hooks() {
  for hook in "$DOTFILES/git/hooks/"*; do
    [ -f "$hook" ] || continue
    ln -sf "$hook" "$DOTFILES/.git/hooks/$(basename "$hook")"
  done
}

# 從 .env.example 建立 .env（不覆蓋既有檔案）
setup_secrets() {
  for tmpl in "$DOTFILES/secrets/"*.env.example; do
    [ -f "$tmpl" ] || continue
    local env_file="${tmpl%.example}"
    if [ ! -f "$env_file" ]; then
      cp "$tmpl" "$env_file"
      echo "[secrets] created $(basename "$env_file") from $(basename "$tmpl")"
    fi
  done
}

create_symlinks
install_hooks
setup_secrets
