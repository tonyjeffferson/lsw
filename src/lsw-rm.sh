#!/bin/bash

if whiptail --title "Setup" --yesno "Do you want to revert all changes? WARNING: This will ERASE all Docker Compose data!" 8 78; then
    docker compose down --rmi=all --volumes
    rm compose.yaml
    exit 0
fi