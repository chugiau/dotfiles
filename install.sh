#!/bin/sh

# 自動找出所有 .symlink 檔案並建立連結
create_symlinks() {
  for src in $(find ~/.dotfiles -name "*.symlink"); do
    dst="$HOME/.$(basename "${src%.symlink}")"
    ln -sf "$src" "$dst"
  done
}

create_symlinks

