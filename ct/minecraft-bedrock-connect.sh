#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/maddiecs84/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
   _____   .__                                        _____   __       __________             .___                         __     
  /     \  |__|  ____    ____   ____ _______ _____  _/ ____\_/  |_     \______   \  ____    __| _/_______   ____    ____  |  | __ 
 /  \ /  \ |  | /    \ _/ __ \_/ ___\\_  __ \\__  \ \   __\ \   __\     |    |  _/_/ __ \  / __ | \_  __ \ /  _ \ _/ ___\ |  |/ / 
/    Y    \|  ||   |  \\  ___/\  \___ |  | \/ / __ \_|  |    |  |       |    |   \\  ___/ / /_/ |  |  | \/(  <_> )\  \___ |    <  
\____|__  /|__||___|  / \___  >\___  >|__|   (____  /|__|    |__|       |______  / \___  >\____ |  |__|    \____/  \___  >|__|_ \ 
        \/          \/      \/     \/             \/                           \/      \/      \/                      \/      \/ 
                                                                                                                                  
EOF
}
header_info
echo -e "Loading..."
APP="minecraft-bedrock-connect"
var_disk="8"
var_cpu="1"
var_ram="512"
var_os="alpine"
var_version="3.18"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
  if ! apk -e info newt >/dev/null 2>&1; then
    apk add -q newt
  fi
  while true; do
    CHOICE=$(
      whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUPPORT" --menu "Select option" 11 58 1 \
        "1" "Check for Docker Updates" 3>&2 2>&1 1>&3
    )
    exit_status=$?
    if [ $exit_status == 1 ]; then
      clear
      exit-script
    fi
    header_info
    case $CHOICE in
    1)
      apk update && apk upgrade
      exit
      ;;
    esac
  done
}

start
build_container
description

msg_ok "Completed Successfully!\n"
