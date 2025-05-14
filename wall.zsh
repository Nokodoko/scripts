 #!/bin/zsh

ns=notify-send
$ns "Wallpaper"

 # Directory containing images
 DIR="~/Pictures/"

 # Function to preview images using wezterm imgcat
 preview() {
   local file="$1"
   wezterm imgcat "$file"
 }

 # Use fzf to select an image with preview
 # selected_file=$(fd . -e png ~/Pictures | fzf --preview 'wezterm imgcat {}')
 selected_file=$(fd . -e png -e jpg -d1 ~/Pictures | fzf --preview 'chafa --fill=block --symbols=block -c full -s 1 --size 40x20 {}')

 # Set the selected image as the background using feh
 if [[ -n "$selected_file" ]]; then
   feh --bg-fill "$selected_file"
 else
   echo "No file selected."
 fi
