#!/bin/bash 

#Username (change variable here)
UN=${UN}

#1. Set timezone
echo "ln -sf /usr/share/zoneinfo/America/New_York" >> /etc/localtime

#2. Set clock
echo "hwclock --systohc"
 
#3. Set Location
echo "LANG=en_US.UTF-8" >> /etc/locale.gen
echo "LC_CTYPE=en_US.UTF-8" >> /etc/locale.conf

#4. Adding ${UN}
useradd -m ${UN}

#4. Configure host file
printf "127.0.0.1 localhost/n::1 localhost/n127.0.0.1 blackbox.localdomain blackbox/n192.168.1.1 BusyBox/n192.168.1.154 mobileUnit/n192.168.50.1 asus/n192.168.50.85 p1/n192.168.50.162 p2/n192.168.50.9 p3/n192.168.50.3 mac" >> /etc/hosts

#5. Create hostname
echo "blackbox" >> /etc/hostname

#6. Install packages
pacman -S --no-confirm neovim xorg-server kitty docker kubeadm starship helm feh ssh wget wpa-supplicant netctl dialog 

#7. Make Directories
mkdir -p /home/${UN}/Downloads /home/${UN}/Programs /home/${UN}/.ssh/ /home/${UN}/.zsh/ /home/${UN}/suckless/ 

#8. Retrieve Configs 
alias gc='git clone'

#9. Install neovim
cd /home/${UN}/Programs/
gc "https://github.com/Nokodoko/nvim.git"
cd nvim/ && make install

#10. Install zsh-tooling
cd /home/${UN}/.zsh/
gc "https://github.com/Nokodoko/tooling.git"

#11. Install dwm
cd /home/n0ko/suckless
gc "https://github.com/Nokodoko/n0kodwm.git"
cd n0kodwm/ && make install

#12. Install slstatus
cd /home/${UN}/suckless
gc "https://github.com/Nokodoko/slstatus.git"
cd slstatus/ && make install

#13. Config files
cd ~
gc "https://github.com/Nokodoko/.config.git"

#start iwd
systemctl --now enable iwd

#14. Make rsa-keys 
cd /home/${UN}/.ssh
ssh-keygen -q -t rsa -N '' 

#16. Install font
cd /home/${UN}/Downloads/
wget https://rubjo.github.io/victor-mono/VictorMonoall.zip
tar -xvf VictorMonoall.zip
cd TTF
mv * /usr/share/fonts/TTF/
