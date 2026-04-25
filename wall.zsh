 #!/bin/zsh

ns=notify-send
$ns "Wallpaper"

 # Directory containing images
 DIR="~/Pictures/"

 # Function to preview images using kitty's icat kitten
 preview() {
   local file="$1"
   kitten icat "$file"
 }

 # Use fzf to select an image with preview
 # selected_file=$(fd . -e png ~/Pictures | fzf --preview 'kitten icat {}')
 # neovim :terminal has no sixel/kitty protocol support; fall back to unicode blocks
 # selected_file=$(fd . -e png -e jpg -d1 ~/Pictures | fzf --preview 'chafa -f sixel --size 40x20 {}')
 selected_file=$(fd . -e png -e jpg -d1 ~/Pictures | fzf --preview 'chafa --fill=block --symbols=block -c full -s 1 --size 40x20 {}')

 # Set the selected image as the background using feh
 if [[ -n "$selected_file" ]]; then
   feh --bg-fill "$selected_file"
 else
   echo "No file selected."
 fi
