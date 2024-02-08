#!/bin/sh

# If you would like to do some extra provisioning you may
# add any commands you wish to this file and they will
# be run after the Homestead machine is provisioned.
#
# If you have user-specific configurations you would like
# to apply, you may also create user-customizations.sh,
# which will be run after this script.

# Git
sudo add-apt-repository ppa:git-core/ppa -y
sudo apt update
sudo apt install git -y

git config --global init.defaultbranch main
git config --global core.autocrlf input

# FNM
if ! hash fnm 2>/dev/null; then
    sudo apt install -y curl unzip

    curl -Lf https://mirror.ghproxy.com/https://raw.githubusercontent.com/Schniz/fnm/master/.ci/install.sh \
    | sed 's|https://github.com|https://mirror.ghproxy.com/&|' \
    | bash

    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"

    export FNM_NODE_DIST_MIRROR=https://mirrors.aliyun.com/nodejs-release/
    fnm install --lts

    # npm mirror
    npm config set registry https://registry.npmmirror.com/
fi

# PNPM
if ! hash pnpm 2>/dev/null; then
    npm install -g pnpm
    pnpm setup
fi

# Composer completion
composer completion | sudo tee /etc/bash_completion.d/composer > /dev/null

# Composer mirror
composer config -g repo.pkg_xyz composer https://packagist.phpcomposer.com
composer config -g repos.tencent composer https://mirrors.tencent.com/composer/
composer config -g repo.packagist false

# Proxychains
sudo apt install -y proxychains4
mkdir -p ~/.proxychains
tee ~/.proxychains/proxychains.conf <<EOF
strict_chain
quiet_mode
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]

# Vagrant
#socks5 192.168.56.1 7890

# WSL
#socks5 172.29.32.1 7890
EOF
# 需要防火墙开放 7890 端口入站 TCP 连接
