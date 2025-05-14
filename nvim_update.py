#!/usr/bin/env python3
import os
import shutil

os.chdir("/home/n0ko/Programs/neovim/")
os.system("git pull")
print("Nvim Repo Updated")
os.system("git checkout nightly")
os.system("sudo make clean install")
print("Completed Neovim Nightly Build")

OLD_ALPHA_FILE = (
    "/home/n0ko/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/ui/alpha.lua"
)
OLD_KEYMAPS_FILE = (
    "/home/n0ko/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/keymaps.lua"
)
OLD_HARPOON_FILE = "/home/n0ko/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/harpoon2.lua"

ALPHA_PATH = "/home/n0ko/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/ui/"
HARPOON_PATH = (
    "/home/n0ko/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/editor/"
)
KEYMAPS_PATH = "/home/n0ko/.local/share/nvim/lazy/LazyVim/lua/lazyvim/config/"

NEW_ALPHA_FILE = "/home/n0ko/modified/alpha.lua"
NEW_KEYMAPS_FILE = "/home/n0ko/modified/keymaps.lua"
NEW_HARPOON_FILE = "/home/n0ko/modified/harpoon2.lua"

os.remove(OLD_ALPHA_FILE)
os.remove(OLD_KEYMAPS_FILE)
os.remove(OLD_HARPOON_FILE)

shutil.copyfile(NEW_ALPHA_FILE, os.path.join(ALPHA_PATH, "alpha.lua"))
shutil.copyfile(NEW_KEYMAPS_FILE, os.path.join(KEYMAPS_PATH, "keymaps.lua"))
shutil.copyfile(NEW_HARPOON_FILE, os.path.join(HARPOON_PATH, "harpoon2.lua"))
