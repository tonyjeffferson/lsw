#!/bin/bash

if zenity --question --text "Do you want to revert all changes? WARNING: This will ERASE all Docker Compose data!" --width 360 --height 300; then
    sudo docker compose down --rmi=all --volumes
    rm compose.yaml
    exit 0
fi