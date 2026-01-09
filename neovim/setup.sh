#!/bin/sh

if [ ! -d "NvChad" ]; then
  git clone https://github.com/NvChad/NvChad.git ~/.config/nvim && nvim
fi

mkdir -p "$HOME/.config/nvim/lua"

if [ ! -L "$HOME/.config/nvim/lua/custom" ]; then
  ln -s "$(pwd)" "$HOME/.config/nvim/lua/custom"
fi

