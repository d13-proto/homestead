#!/usr/bin/env bash

# If you would like to do some extra provisioning you may
# add any commands you wish to this file and they will
# be run after the Homestead machine is provisioned.
#
# If you have user-specific configurations you would like
# to apply, you may also create user-customizations.sh,
# which will be run after this script.

# 主机 IP
VAGRANT_HOST_IP="10.0.2.2"

if grep -iq microsoft /proc/version; then
    # Running under Microsoft WSL
    VAGRANT_HOST_IP=$(ip route show | grep -i default | awk '{ print $3}')

    if [ "$VAGRANT_HOST_IP" = 192.168.1.1 ]; then
        # Mirrored mode networking
        VAGRANT_HOST_IP=127.0.0.1
    fi
fi

# 检查命令是否存在
command_exists() {
    hash "$1" 2>/dev/null
}

# Git
if ! command_exists git; then
    sudo add-apt-repository ppa:git-core/ppa -y
    sudo apt update
    sudo apt install -y git
fi

git config --global init.defaultbranch main
git config --global core.autocrlf input

# PostgreSQL
if ! command_exists git; then
    sudo apt install -y postgresql-common
    sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
    sudo apt install -y postgresql

    POSTGRESQL_MAJOR_VERSION=$(psql -V | grep -oE '\b[0-9]+\b' | head -1)

    # Configure Postgres Users
    sudo -u postgres psql -c "CREATE ROLE homestead LOGIN PASSWORD 'secret' SUPERUSER;"

    # Configure Postgres Remote Access
    sudo -u postgres pg_conftool set listen_addresses localhost
    sudo -u postgres tee -a "/etc/postgresql/$POSTGRESQL_MAJOR_VERSION/main/pg_hba.conf" <<EOF

# Vagrant host
host	all		all		$VAGRANT_HOST_IP/32		scram-sha-256
EOF

fi

# FNM
if ! command_exists fnm; then
    sudo apt install -y curl unzip

    curl -Lf https://mirror.ghproxy.com/https://raw.githubusercontent.com/Schniz/fnm/master/.ci/install.sh |
        sed 's|https://github.com|https://mirror.ghproxy.com/&|' |
        bash

    export PATH="$HOME/.local/share/fnm:$PATH"
    eval "$(fnm env)"

    export FNM_NODE_DIST_MIRROR=https://mirrors.aliyun.com/nodejs-release/
    fnm install --lts
fi

# NPM mirror
npm config set registry https://registry.npmmirror.com/

# PNPM
if ! command_exists pnpm; then
    npm install -g pnpm
    pnpm setup
fi

# Python
if ! command_exists pip; then
    sudo apt install -y python3 python3-pip
fi

# Pypi mirror
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

# Rust
if ! command_exists cargo; then
    export RUSTUP_UPDATE_ROOT=https://mirror.iscas.ac.cn/rustup/rustup
    curl https://sh.rustup.rs -sSf |
        bash -s -- -y

    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
fi

# crates.io mirror
tee "$HOME/.cargo/config" <<EOF
[source.crates-io]
replace-with = 'cernet'

[source.cernet]
registry = "sparse+https://mirrors.cernet.edu.cn/crates.io-index/"
EOF

# Composer completion
composer completion | sudo tee /etc/bash_completion.d/composer >/dev/null

# Composer mirror
composer config -g repositories.pkg_xyz composer https://packagist.phpcomposer.com
composer config -g repositories.tencent composer https://mirrors.tencent.com/composer/
composer config -g repositories.packagist false

# Proxychains
if ! command_exists proxychains; then
    sudo apt install -y proxychains4
fi

mkdir -p "$HOME/.proxychains"
tee "$HOME/.proxychains/proxychains.conf" <<EOF
strict_chain
quiet_mode
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 $VAGRANT_HOST_IP 7890
EOF
# 需要防火墙开放 7890 端口入站 TCP 连接
