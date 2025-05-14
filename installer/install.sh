##!/bin/bash
#mkdir -p ~/.config
#pushd ~/.config
#
#mkdir -p ~/Downloads
#pushd ~/Downloads
#
#sudo pacman -Sy wget unzip go curl lua luarocks feh xorg xorg-xinit go python ansible terraform python-pip polybar lynx dunst sxhkd ghc xclip sxiv arandr tldr kubectl npm libnotify pavucontrol jq screenkey pipewire pipewire-alsa pipewire-pulse pipewire-jack bluez bluez-utils scrot openssh git iwd --noconfirm
#systemctl --user enable pipewire.service
#systemctl --user start pipewire.service
#systemctl --user enable pipewire-pulse.service
#systemctl --user start pipewire-pulse.service
#sudo systemctl enable bluetooth.service
#sudo systemctl start bluetooth.service
#sudo chown /usr/share/lua/5.4/
#sudo chmod u+w /usr/share/lua/5.4/
#sudo chown /usr/bin/
#sudo chmod u+w /usr/bin/
#luarocks install mobdebug dkjson luasocket
#wget 'http//github.io/victor-mono/VictorMono.zip'
#popd
#mkdir -p ~/.local/share/fonts
#pushd ~/.local/share/fonts
#unzip ~/VictorMonoAll.zip
#fc-cache -v
#popd
#mkdir -p ~/Programs/
#
#curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
#cargo install lsd starship fd-find ripgrep wezterm bat zoxide
#echo "source \$HOME/.cargo/env" >> ~/.bashrc

#go install github.com/junegunn/fzf@lastest
#links=(
#	"https://github.com/DataDog/datadog-api-client-go.git"
#	"https://github.com/DataDog/datadog-api-client-python.git"
#	"https://github.com/LazyVim/starter.git"
#	"https://github.com/OthersideAI/self-operating-computer.git"
#	"https://github.com/TheR1D/shell_gpt.git"
#	"https://github.com/ankitpokhrel/jira-cli.git"
#	"https://github.com/bacara/powerline-for-polybar.git"
#	"https://github.com/betaboon/nerd-fonts-patcher.git"
#	"https://github.com/bitfield/script.git"
#	"https://github.com/buzz-language/buzz.git"
#	"https://github.com/canihavesomecoffee/udis86"
#	"https://github.com/chadmed/asahi-audio.git"
#	"https://github.com/diegonehab/luasocket.git"
#	"https://github.com/djpohly/dwl.git"
#	"https://github.com/dunst-project/dunst.git"
#	"https://github.com/hwchase17/langchain.git"
#	"https://github.com/hyprwm/Hyprland"
#	"https://github.com/hyprwm/hyprland-protocols"
#	"https://github.com/jmorganca/ollama.git"
#	"https://github.com/junegunn/fzf"
#	"https://github.com/kelseyhightower/kubernetes-the-hard-way.git"
#	"https://github.com/kmonad/kmonad"
#	"https://github.com/kovidgoyal/kitty"
#	"https://github.com/libbpf/bpftool.git"
#	"https://github.com/lizrice/learning-ebpf.git"
#	"https://github.com/llvm/llvm-project.git"
#	"https://github.com/marco-lancini/goscan.git"
#	"https://github.com/neomutt/neomutt.git"
#	"https://github.com/neovim/neovim"
#	"https://github.com/noahgorstein/jqp.git"
#	"https://github.com/pandas-dev/pandas.git"
#	"https://github.com/pytorch/pytorch.git"
#	"https://github.com/rubjo/victor-mono.git"
#	"https://github.com/rust-lang-nursery/rust-cookbook.git"
#	"https://github.com/torch/torch7.git"
#	"https://github.com/vnmakarov/mir"
#	"https://github.com/waycrate/swhkd"
#	"https://github.com/wee-slack/wee-slack.git"
#	"https://github.com/wez/wezterm.git"
#	"https://github.com/zellij-org/zellij.git"
#	"https://github.com/ziglang/zig.git"
#	"https://github.com/zsh-users/zsh-autosuggestions.git"
#)
#
#for link in ${links[@]}; do
#	git clone $link
#done
#
#pushd ~/Programs/neovim
#git checkout nightly
#sudo make install -j$(nproc)
#popd
pushd ~/Programs
git clone "https://aur.archlinux.org/yay.git"
pushd ~/Programs/yay
makepkg -sri --noconfirm

yay -S picom ttf-victor-mono-nerd slack teams --noconfirm

pushd ~/.config
configs=("https://github.com/Nokodoko/dwm-headless.git"
  "https://github.com/Nokodoko/lazy_n0kovim.git"
  "https://github.com/Nokodoko/vimwiki.git"
  "https://github.com/Nokodoko/lua_programs.git"
  "https://github.com/Nokodoko/nvim.git"
  "https://github.com/Nokodoko/opsProject.git"
  "https://github.com/Nokodoko/wezterm.git"
  "https://github.com/Nokodoko/networking.git"
  "https://github.com/Nokodoko/Datadog.git"
  "https://github.com/Nokodoko/Dockerfiles.git"
  "https://github.com/Nokodoko/dataFeed.git"
  "https://github.com/Nokodoko/k8s_the_hard_way.git"
  "https://github.com/Nokodoko/client.git"
  "https://github.com/Nokodoko/sort.git"
  "https://github.com/Nokodoko/servers.git"
  "https://github.com/Nokodoko/scrape.git"
  "https://github.com/Nokodoko/osPlay.git"
  "https://github.com/Nokodoko/kmonad.git"
  "https://github.com/Nokodoko/interpjs.git"
  "https://github.com/Nokodoko/dunst.git"
  "https://github.com/Nokodoko/starship.git"
)

for config in ${configs[@]}; do
  git clone $config
done

mkdir -p ~/programming
pushd ~/programming

programming=(
  "https://github.com/Nokodoko/rust.git"
  "https://github.com/Nokodoko/lua_projects.git"
  "https://github.com/Nokodoko/go_projects.git"
  "https://github.com/Nokodoko/python_projects.git"
)

for program in ${programming[@]}; do
  git clone $program
done

mkdir -p ~/scripts
pushd ~/scripts

git clone "https://github.com/Nokodoko/scripts.git"

pushd ~
mkdir -p ~/.zsh/
git clone"https://github.com/Nokodoko/tooling.git"
