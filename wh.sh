#!/bin/bash

#COLORS
function capColor() {
    TEXT=$1
    gum style --foreground "#118DFF" "$TEXT"
}

function redColor() {
    TEXT=$1
    gum style --foreground "#D82C20" "$TEXT"
}

gum style \
    --border double \
    --padding "1" \
    "Capacity Warehouses"

#FLAGS
while getopts 'q' OPTION; do
    case "$OPTION" in
        q)
    echo "Choose your $(redColor "warehouse") $(capColor "for query")"
    TYPE=$(gum choose "production" "playground")
    DATABASE=$(gum filter < ~/scripts/warehouses/$(command ls ~/scripts/warehouses/ | flist "Warehouses"))
    ~/scripts/sqlQuery/$TYPE/$DATABASE
    exit 0
            ;;
        *)
            echo "Invalid flag"
            exit 1
            ;;
    esac
done

#BASE PROGRAM
echo "Choose  your $(redColor "warehouse")"
TYPE=$(gum choose "production" "playground")
DATABASE=$(gum filter < ~/scripts/warehouses/$(command ls ~/scripts/warehouses/ | flist "Warehouses"))

~/scripts/warehouses/$TYPE/$DATABASE
