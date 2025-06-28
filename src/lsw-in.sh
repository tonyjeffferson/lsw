#!/bin/bash

# SELinux detector
selinux_det () {

    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        if [[ "$selinux_status" == "Enforcing" || "$selinux_status" == "Permissive" ]]; then
            title="LSW"
            msg="LSW is not compatible with SELinux. Aborting..."
            _msgbox_
            exit 7
        else
            return
        fi
    fi

}

# check dependencies
depcheck () {

    if [[ "$ID_LIKE" == *debian* ]] || [[ "$ID_LIKE" == *ubuntu* ]] || [ "$ID" == "ubuntu" ]; then
        local _packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin dialog freerdp3-sdl git iproute2 libnotify-bin netcat-openbsd)
        insta ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
    elif [ "$ID" == "debian" ]; then
        local _packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin dialog freerdp3-sdl git iproute2 libnotify-bin netcat-openbsd)
        insta ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
    elif [[ "$ID_LIKE" =~ (rhel|fedora) ]] || [[ "$ID" =~ (fedora) ]]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        local _packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin curl dialog freerdp git iproute libnotify nmap-ncat)
    elif [[ "$ID" =~ ^(arch|cachyos)$ ]] || [[ "$ID_LIKE" == *arch* ]] || [[ "$ID_LIKE" == *archlinux* ]]; then
        local _packages=(docker docker-compose curl dialog freerdp git iproute2 libnotify gnu-netcat)
    elif [ "$ID_LIKE" == "suse" ] || [ "$ID" == "suse" ]; then
        local _packages=(docker docker-compose curl dialog freerdp git iproute2 libnotify-tools netcat-openbsd)
    fi
    _install_
    getent group docker || true && sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker
    sudo systemctl enable --now docker
    sleep 2

}

# install windows on docker
windocker () {

    # get compose file
    cd $HOME
    wget -nc https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/compose.yaml
    # make necessary adjustments to compose file
    local total_kb=$(grep MemTotal /proc/meminfo | awk '{ print $2 }')
    local available_kb=$(grep MemAvailable /proc/meminfo | awk '{ print $2 }')
    local total_gb=$(( total_kb / 1024 / 1024 ))
    local available_gb=$(( available_kb / 1024 / 1024 ))
    _cram=$(( total_gb / 3 ))
    # Enforce minimum
    if (( _cram < 4 )); then
        local title="Error"
        local msg="System RAM too low. At least 12GB total is required to continue."
        _msgbox_
        exit 1
    fi
    # Enforce availability with 1GB buffer (to avoid rounding issues)
    if (( available_gb < (_cram + 1) )); then
        local title="Error"
        local msg="Not enough free RAM. Close some applications and try again."
        _msgbox_
        exit 1
    fi
    # Cap at 16GB
    if (( _cram > 16 )); then
        _winram=16
    else
        _winram=$_cram
    fi
    local _total_threads=$(nproc)
    _ccpu=$(( _total_threads / 2 ))
    if (( _ccpu < 2 )); then
        local title="Error"
        local msg="Not enough space to install Windows, minimum 40GB."
        _msgbox_
        exit 6
    fi
    _wincpu="$_ccpu"
    _cdir=""
    _cdir=$(whiptail --inputbox "Enter location for Windows installation. Leave empty for ${HOME}/Windows." 10 30 3>&1 1>&2 2>&3)
    if [ -z "$_cdir" ]; then
        mkdir -p Windows
        _windir="${HOME}/Windows"
    elif [ ! -d "$_cdir" ]; then
        local title="Error"
        local msg="Invalid path for installation, try again."
        _msgbox_
        exit 2
    else
        _windir="$_cdir"
    fi
    _csize=$(whiptail --inputbox "Enter Windows disk (C:) size in GB. Leave empty to use 100GB." 10 30 3>&1 1>&2 2>&3)
    local available_gb=$(df -BG "$_windir" | awk 'NR==2 { gsub("G","",$4); print $4 }')
    if [ -z "$_csize" ]; then
        _winsize="100"
    else
        _winsize="$_csize"
    fi
    if (( _winsize < "40" )); then
        local title="Error"
        local msg="Not enough space to install Windows, minimum 40GB."
        _msgbox_
        exit 4
    fi
    if (( available_gb < _winsize )); then
        local title="Error"
        local msg="Not enough disk space in $_cdir: ${_winsize} GB required, ${available_gb} GB available."
        _msgbox_
        exit 3
    fi
    sed -i "s|^\(\s*RAM_SIZE:\s*\).*|\1\"${_winram}G\"|" compose.yaml
    sed -i "s|^\(\s*CPU_CORES:\s*\).*|\1\"${_wincpu}\"|" compose.yaml
    sed -i "s|^\(\s*device:\s*\).*|\1\"${_windir}\"|" compose.yaml
    sed -i "s|^\(\s*DISK_SIZE:\s*\).*|\1\"${_winsize}\"|" compose.yaml
    if command -v konsole &> /dev/null; then
        setsid konsole --noclose -e  "sudo docker compose --file ./compose.yaml up" >/dev/null 2>&1 < /dev/null &
    elif command -v gnome-terminal &> /dev/null; then
        setsid gnome-terminal -- bash -c "sudo docker compose --file ./compose.yaml up; exec bash" >/dev/null 2>&1 < /dev/null &
    fi

}

# configure winapps
winapp_config () {

    if [[ "$ID_LIKE" == *debian* ]] || [[ "$ID_LIKE" == *ubuntu* ]] || [ "$ID" == "ubuntu" ] || [ "$ID" == "debian" ]; then
        local _packages=(freerdp3-x11)
        _install_
    fi
    cd $HOME
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/winapps.conf
    mkdir -p .config/winapps
    mv winapps.conf .config/winapps/
    mv compose.yaml .config/winapps/
    sleep 2
    docker compose --file ~/.config/winapps/compose.yaml stop
    sleep 2
    docker compose --file ~/.config/winapps/compose.yaml start
    sleep 10
    local title="LSW"
    local msg="Now a test for RDP will be performed. It should show you the Windows 10 subsystem in a window, and it is safe to close once it logs in."
    _msgbox_
    xfreerdp3 /u:"lsw" /p:"lsw" /v:127.0.0.1 /cert:tofu
    sleep 10
    bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)

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
    wget wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/menu/lsw-desktop.desktop
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/lsw-desktop.png
    sleep 1
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

rmlsw () {

    if whiptail --title "Setup" --yesno "Do you want to revert all changes? WARNING: This will ERASE all Docker Compose data!" 8 78; then
        bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)
        docker compose --file ~/.config/winapps/compose.yaml stop
        sleep 2
        docker compose down --rmi=all --volumes
        sudo rm /usr/bin/lsw-on*
        sudo rm /usr/bin/lsw-off*
        sudo rm /usr/bin/lsw-refresh*
        sudo rm /usr/share/applications/lsw-on.desktop
        sudo rm /usr/share/applications/lsw-off.desktop
        sudo rm /usr/share/applications/lsw-refresh.desktop
        rm -rf ~/.config/winapps
        exit 0
    else
        return
    fi

}

lswcfg () {

    # step 2 - winapps config
    if whiptail --title "Setup" --yesno "Is the Windows installation finished?" 8 78; then
        lsw_menu
        exit 0
    else
        if whiptail --title "Setup" --yesno "Do you want to revert all changes? WARNING: This will ERASE all Docker Compose data!" 8 78; then
            docker compose down --rmi=all --volumes
            exit 1
        fi
    fi

}

# runtime
. /etc/os-release
source <(curl -s https://raw.githubusercontent.com/psygreg/linuxtoys/refs/heads/main/src/linuxtoys.lib)
# step 1 - docker setup
if [ -e /dev/kvm ]; then
    selinux_det
    depcheck
    # menu
    while :; do

        CHOICE=$(whiptail --title "LSW" --menu "Linux Subsystem for Windows:" 25 78 16 \
            "0" "Install Standalone" \
            "1" "Install WinApps" \
            "2" "Uninstall" \
            "3" "Cancel" 3>&1 1>&2 2>&3)

        exitstatus=$?
        if [ $exitstatus != 0 ]; then
            # Exit the script if the user presses Esc
            break
        fi

        case $CHOICE in
        0) windocker && lswcfg ;;
        1) winapp_config ;;
        2) rmlsw && break ;;
        3 | q) break ;;
        *) echo "Invalid Option" ;;
        esac
    done
else
    title="LSW"
    msg="KVM unavailable. Enable Intel VT-x or AMD SVM on BIOS and try again."
    _msgbox_
    exit 5
fi
