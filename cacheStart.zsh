#!/bin/bash 

mkdir /tmp/chrome
ln -sf /tmp/chrome ~/.cache/google-chrome/Profile 1/
ln -sf /tmp/chrome ~/.cache/google-chrome/Profile 2/
ln -sf /tmp/chrome ~/.cache/google-chrome/Default/

mkdir /tmp/qute
ln -sf /tmp/qute ~/.cache/qutebrowser/http/
ln -sf /tmp/qute ~/.cache/qutebrowser/qute/
ln -sf /tmp/qute ~/.cache/qutebrowser/webengine/

mkdir /tmp/kitty
ls -sf /tmp/kitty ~/.cache/kitty/shell.history
ls -sf /tmp/kitty ~/.cache/kitty/main.json
ls -sf /tmp/kitty ~/.cache/kitty/panel.json


mkdir /tmp/nvim
ls -sf /tmp/nvim ~/.cache/nvim/nvim/
ls -sf /tmp/nvim ~/.cache/nvim/luacache
ls -sf /tmp/nvim ~/.cache/nvim/luacache_modpaths
ls -sf /tmp/nvim ~/.cache/nvim/luacache_chunks

mkdir /tmp/electron
ls -sf /tmp/electron ~/.cache/electron/election
ls -sf /tmp/electron ~/.cache/electron/chromedriver-v1.8.0-linux-x64.zip
ls -sf /tmp/electron ~/.cache/electron/SHASUMS256.txt-1.8.0

