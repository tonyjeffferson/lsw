#!/bin.bash

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
windocker () {

    # get compose file
    cd $HOME
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/compose.yaml
    # make necessary adjustments to compose file
    _cram=""
    _cram=$(whiptail --inputbox "Enter RAM allocation for Windows container, in GB. Leave empty to use 12GB." 10 30 3>&1 1>&2 2>&3)
    local available_kb=$(grep MemAvailable /proc/meminfo | awk '{ print $2 }')
    local available_gb=$(echo "$available_kb / 1048576" | bc)
    if (( _cram > available_gb )); then
        local title="Error"
        local msg="Not enough RAM: ${_cram} GB, available: ${available_gb} GB."
        _msgbox_
        return
    else
        if [ -z "$_cram" ]; then
            _winram="12"
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
    if [ -z "$_cdir" ] || [ ! -f "$_cdir" ]; then
        local title="Error"
        local msg="Invalid path for installation, try again."
        _msgbox_
        return
    else
        _windir="$_cdir"
    fi
    sed -i "s|^\(\s*RAM_SIZE:\s*\).*|\1\"${_winram}G\"|" compose.yaml
    sed -i "s|^\(\s*CPU_CORES:\s*\).*|\1\"${_wincpu}\"|" compose.yaml
    sed -i "s|^\(\s*device:\s*\).*|\1\"${_windir}\"|" compose.yaml
    sudo docker compose --file ./compose.yaml up

}

# configure winapps
winapp_config () {

    cd $HOME
    wget https://raw.githubusercontent.com/psygreg/lsw/refs/heads/main/src/winapps.conf
    mkdir -p .config/winapps
    mv winapps.conf .config/winapps/
    mv compose.yaml .config/winapps/
    git clone https://github.com/winapps-org/winapps.git
    cd winapps
    bash <(curl https://raw.githubusercontent.com/winapps-org/winapps/main/setup.sh)

}

