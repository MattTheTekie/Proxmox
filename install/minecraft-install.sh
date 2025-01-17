#!/usr/bin/env bash

# Copyright (c) 2021-2023 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apk add newt
$STD apk add curl
$STD apk add openssh
$STD apk add nano
$STD apk add mc
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
$STD apk add docker
$STD rc-service docker start
$STD rc-update add docker default
msg_ok "Installed Docker"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}
DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")

msg_info "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -sSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_LATEST_VERSION/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
msg_ok "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"

whiptail --title "Minecraft Server" --msgbox "Configure your Minecraft server" 11 58

MINECRAFT_SERVER_PORT=25565

WORLD_NAME=$(whiptail --inputbox "What would you like to call your world?" 11 58 "My World" --title "World Name" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    exit 1
fi
if [ -z "$WORLD_NAME" ]
then
      WORLD_NAME="My World"
fi

DEFAULT_SEED="5890866665536842607" # Cherry Blossom
# Stronghold Below 22061
LEVEL_SEED=$(whiptail --inputbox "Enter your level seed?" 11 58 "$DEFAULT_SEED" --title "Level Seed" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    exit 1
fi
if [ -z "$LEVEL_SEED" ]
then
      LEVEL_SEED=$DEFAULT_SEED
fi

GAME_MODE=$(whiptail --title "Game mode" --radiolist "Choose a game mode" 11 58 4 \
  "creative" "" ON \
  "survival" "" OFF \
  "adventure" "" OFF \
  3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    exit 1
fi

DIFFICULTY=$(whiptail --title "Difficulty" --radiolist "Choose a difficulty" 11 58 4 \
  "peaceful" "" OFF \
  "easy" "" ON \
  "normal" "" OFF \
  "hard" "" OFF \
  3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
    exit 1
fi

if whiptail --title "Backups" --yesno "Would you like to enable default backup settings?" 11 58; then
    BACKUPS=1
else
    BACKUPS=0
fi

# If you cannot understand this, read Bash_Shell_Scripting/Conditional_Expressions again.
if whiptail --title "Allow list" --yesno "Set up an allow list?" 8 78; then
    USE_ALLOW_LIST="true"
    ALLOW_LIST=$(whiptail --inputbox "Enter allowed players (comma separated)?" 11 58 "" --title "Allowed players" 3>&1 1>&2 2>&3)
else
    USE_ALLOW_LIST="false"
    ALLOW_LIST=""
fi


cat >/root/config.yml <<EOF
containers:
  minecraft:
    # Name of the container
    - name: minecraft_server
      worlds:
        - /server/worlds/$WORLD_NAME
schedule:
  # This will perform a backup every 3 hours.
  # At most this will generate 8 backups a day.
  interval: 3h
trim:
  # Keep all backups for the last two days (today and yesterday)
  # Keep at least one backup for the last 14 days
  # Keep at least two backups per world
  trimDays: 2
  keepDays: 14
  minKeep: 2
EOF

cat >/root/minecraft-server.yaml <<EOF
version: '3.8'

services:
  minecraft-server:
    image: itzg/minecraft-server
    container_name: minecraft_server
    environment:
      EULA: "TRUE"
      GAMEMODE: $GAME_MODE
      DIFFICULTY: $DIFFICULTY
      LEVEL_NAME: "$WORLD_NAME"
      ALLOW_LIST: "$USE_ALLOW_LIST"
      ALLOW_LIST_USERS: "$ALLOW_LIST"
      LEVEL_SEED: "$LEVEL_SEED"
    ports:
      - $MINECRAFT_SERVER_PORT:25565/tcp
    volumes:
      - /opt/minecraft/server:/data
    stdin_open: true
    tty: true
    restart: unless-stopped
EOF

if [ $BACKUPS = 1 ]; then
  cat >>/root/minecraft-server.yaml <<EOF
  backup:
    image: kaiede/minecraft-backup
    restart: always
    container_name: minecraft_backup
    depends_on:
      - "minecraft-server"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/minecraft/backups:/backups
      - /opt/minecraft/server:/server
      - /root/config.yml:/backups/config.yml
    tty: true
EOF
fi

## Start configuring dashboard
cat >/root/nginx.conf <<EOF
events {
    worker_connections 1024;
}

http {
    include mime.types;
    sendfile on;

    server {
        listen 80;
        listen [::]:80;

        resolver 127.0.0.11;
        autoindex off;

        server_name _;
        server_tokens off;

        root /app/static;
        gzip_static on;
    }
}
EOF

SERVER_ADDR="$(ip -4 -o addr show eth0 | awk '{print $4}' | cut -d "/" -f 1):$MINECRAFT_SERVER_PORT"
cat >/root/dashboard.html <<EOF
<!DOCTYPE html>
<html>
  <body>
    <h1>Minecraft Server - $WORLD_NAME</h1>
    <p>
      Connect to $WORLD_NAME at $SERVER_ADDR
    </p>
  </body>
</html>
EOF

cat >>/root/minecraft-server.yaml <<EOF
  dashboard:
    image: nginx:alpine
    restart: always
    container_name: minecraft_dashboard
    ports:
      - "80:80"
    environment:
      - NGINX_PORT=80
    volumes:
      - /root/nginx.conf:/etc/nginx/nginx.conf
      - /root/dashboard.html:/app/static/index.html
    tty: true
EOF
## End configuring dashboard

motd_ssh
customize

$DOCKER_CONFIG/cli-plugins/docker-compose -f /root/minecraft-server.yaml up --detach

## docker exec -it minecraft_server bash send-command gamerule showcoordinates true

msg_ok "Installed Minecraft Server"
msg_ok "Connect to $WORLD_NAME at $SERVER_ADDR"
