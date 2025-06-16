#!/bin/bash

# check dependencies
depcheck () {

    if [[ "$ID_LIKE" == *debian* ]] || [[ "$ID_LIKE" == *ubuntu* ]] || [ "$ID" == "debian" ] || [ "$ID" == "ubuntu" ]; then
        local _packages=(docker.io curl dialog freerdp3-x11 git iproute2 libnotify-bin netcat-openbsd)
    elif [[ "$ID_LIKE" =~ (rhel|fedora) ]] || [[ "$ID" =~ (fedora) ]]; then
        local _packages=(docker docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin curl dialog freerdp git iproute libnotify nmap-ncat)
    elif [[ "$ID" =~ ^(arch|cachyos)$ ]] || [[ "$ID_LIKE" == *arch* ]] || [[ "$ID_LIKE" == *archlinux* ]]; then
        local _packages=(docker curl dialog freerdp git iproute2 libnotify gnu-netcat)
    elif [ "$ID_LIKE" == "suse" ] || [ "$ID" == "suse" ]; then
        local _packages=(docker curl dialog freerdp git iproute2 libnotify-tools netcat-openbsd)
    fi
    _install_

}

# install windows on docker
## TODO ADD ADDITIONAL DISKS OPTION
windocker () {

    # get compose file
    cd $HOME
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/compose.yaml
    # make necessary adjustments to compose file
    _cram=""
    _cram=$(whiptail --inputbox "Enter RAM allocation for Windows container, in GB. Leave empty to use 8GB." 10 30 3>&1 1>&2 2>&3)
    local available_kb=$(grep MemAvailable /proc/meminfo | awk '{ print $2 }')
    local available_gb=$(echo "$available_kb / 1048576" | bc)
    if (( _cram > available_gb )); then
        local title="Error"
        local msg="Not enough RAM: ${_cram} GB, available: ${available_gb} GB."
        _msgbox_
        return
    else
        if [ -z "$_cram" ]; then
            _winram="8"
        else
            _winram="$_cram"
        fi
    fi
    _ccpu=""
    _ccpu=$(whiptail --inputbox "Enter number of CPU cores for Windows container. Leave empty to use 4." 10 30 3>&1 1>&2 2>&3)
    local available_cpu=$(nproc)
    if (( _ccpu > available_cpu )); then
        local title="Error"
        local msg="Not enough CPU cores: ${_cram}, available: ${available_gb}."
        _msgbox_
        return
    else
        if [ -z "$_ccpu" ]; then
            _wincpu="4"
        else
            _wincpu="$_ccpu"
        fi
    fi
    _cdir=""
    _cdir=$(whiptail --inputbox "Enter location for Windows installation." 10 30 3>&1 1>&2 2>&3)
    if [ -z "$_cdir" ] || [ ! -d "$_cdir" ]; then
        local title="Error"
        local msg="Invalid path for installation, try again."
        _msgbox_
        return
    else
        _windir="$_cdir"
    fi
    _csize=$(whiptail --inputbox "Enter Windows disk (C:) size in GB. Leave empty to use 120GB." 10 30 3>&1 1>&2 2>&3)
    local available_gb=$(df -BG "$_cdir" | awk 'NR==2 { gsub("G","",$4); print $4 }')
    if [ -z "$_csize" ]; then
        _winsize="120"
    else
        _winsize="$_csize"
    fi
    if (( _winsize < "50" )); then
        local title="Error"
        local msg="Not enough space to install Windows, minimum 50GB."
        _msgbox_
        return
    fi
    if (( available_gb < _winsize )); then
        local title="Error"
        local msg="Not enough disk space in $_cdir: ${_winsize} GB required, ${available_gb} GB available."
        _msgbox_
        return
    fi
    sed -i "s|^\(\s*RAM_SIZE:\s*\).*|\1\"${_winram}G\"|" compose.yaml
    sed -i "s|^\(\s*CPU_CORES:\s*\).*|\1\"${_wincpu}\"|" compose.yaml
    sed -i "s|^\(\s*device:\s*\).*|\1\"${_windir}\"|" compose.yaml
    sed -i "s|^\(\s*DISK_SIZE:\s*\).*|\1\"${_winsize}\"|" compose.yaml
    if command -v konsole &> /dev/null; then
        setsid konsole --noclose -e sudo docker compose --file ./compose.yaml up >/dev/null 2>&1 < /dev/null &
    elif command -v gnome-terminal &> /dev/null; then
        setsid gnome-terminal -- bash -c "sudo docker compose --file ./compose.yaml up; exec bash" >/dev/null 2>&1 < /dev/null &
    fi

}

# configure winapps
winapp_config () {

    cd $HOME
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/winapps.conf
    mkdir -p .config/winapps
    mv winapps.conf .config/winapps/
    mv compose.yaml .config/winapps/
    docker compose --file ~/.config/winapps/compose.yaml stop
    docker compose --file ~/.config/winapps/compose.yaml start
    git clone https://github.com/winapps-org/winapps.git
    cd winapps
    local title="LSW"
    local msg="Now a test for RDP will be performed. It should show you the Windows 10 subsystem in a window, and it is safe to close once it logs in."
    _msgbox_
    xfreerdp3 /u:"lsw" /p:"lsw" /v:127.0.0.1 /cert:tofu
    ./setup.sh
    cd ..
    rm winapps

}

# configure LSW menu entries
lsw_menu () {

    cd $HOME
    mkdir -p lsw
    cd lsw
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/menu/lsw-off.desktop
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/menu/lsw-on.desktop
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/menu/lsw-refresh.desktop
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-off.sh
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-on.sh
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-refresh.sh
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-off.png
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-on.png
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-refresh.png
    sudo mv *.desktop /usr/share/applications/
    sudo mv *.sh /usr/bin/
    sudo mv *.png /usr/bin/
    cd /usr/bin
    sleep 1
    chmod +x lsw-refresh.sh
    chmod +x lsw-on.sh
    chmod +x lsw-off.sh
    cd $HOME
    sleep 1
    rm -rf lsw
    local title="LSW"
    local msg="All done. Enjoy your Windows apps."
    _msgbox_

}

# runtime
. /etc/os-release
source <(curl -s https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/linuxtoys.lib)
# step 1 - docker setup
depcheck
windocker
# step 2 - winapps config
if whiptail --title "Setup" --yesno "Is the Windows installation finished?" 8 78; then
    winapp_config
    lsw_menu
    exit 0
else
    if whiptail --title "Setup" --yesno "Do you want to revert all changes? WARNING: This will ERASE all Docker Compose data!" 8 78; then
        docker compose down --rmi=all --volumes
        rm compose.yaml
        exit 1
    fi
fi
