Dependencies:
1. ripgrep
2. fzf

To replace dmenu with fzf run:
`sed 's/dmenu=.*//g;s/dmenu/fzf/g *`

WIP to make scripts automatically consumable by others. In the meantime, replace dmenu with a fuzzy finder (I just used fzf a lot). Alos replace notify-send and dunstify with terminal-notifier. 
