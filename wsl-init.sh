#!/usr/bin/env bash

set -euo pipefail

WSL_USER_NAME=$(whoami)
WSL_USER_GROUP=$(id -gn)
HOMESTEAD_DIR=$(dirname "$(realpath "$0")")

pushd "$HOMESTEAD_DIR"

if [ -z "${PHP_VERSION:-}" ]; then
    echo -n "PHP default version [8.2]: "
    read -r PHP_VERSION

    PHP_VERSION="${PHP_VERSION:-8.2}"
fi

mkdir -p ~/.homestead-features
echo "$WSL_USER_NAME" > ~/.homestead-features/wsl_user_name
echo "$WSL_USER_GROUP" > ~/.homestead-features/wsl_user_group

# Update System Packages
sudo apt update && sudo apt upgrade -y

# sudo apt install -y software-properties-common curl

# Install Some PPAs
sudo apt-add-repository ppa:ondrej/php -y
sudo apt-add-repository ppa:chris-lea/redis-server -y

sudo apt update

# Install Nginx
sudo apt install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages nginx

sudo rm -f /etc/nginx/sites-enabled/default
sudo rm -f /etc/nginx/sites-available/default

# Create a configuration file for Nginx overrides.
mkdir -p ~/.config/nginx
touch ~/.config/nginx/nginx.conf
sudo ln -sf "/home/$WSL_USER_NAME/.config/nginx/nginx.conf" /etc/nginx/conf.d/nginx.conf

# Add $WSL_USER_NAME User To WWW-Data
sudo usermod -a -G www-data "$WSL_USER_NAME"

# chmod o+rx ~

sudo service nginx restart

# Install PHP
sudo "./scripts/features/php$PHP_VERSION.sh"
sudo service "php$PHP_VERSION-fpm" restart

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Redis, Memcached, & Beanstalk
sudo apt install -y redis-server memcached
sudo systemctl enable redis-server
sudo service redis-server start

# One last upgrade check
sudo apt upgrade -y

# Clean Up
sudo apt -y autoremove
sudo apt -y clean
# chown -R "$WSL_USER_NAME:$WSL_USER_GROUP" "/home/$WSL_USER_NAME"
# sudo chown -R "$WSL_USER_NAME:$WSL_USER_GROUP" "/usr/local/bin"

# Setup Homestead repo
composer install

cp -i ./resources/Homestead-wsl.yaml ./Homestead.yaml
cp -i ./resources/after.sh ./after.sh
cp -i ./resources/aliases ./aliases

# Run after.sh
bash ./after.sh

echo "Appending the following to $HOME/.bashrc"
tee -a ~/.bashrc <<EOF

# Composer Global Bin
PATH="$(composer config -g home 2>/dev/null)/vendor/bin:\$PATH"

HOMESTEAD_DIR=$HOMESTEAD_DIR

homestead() {
    pushd "\$HOMESTEAD_DIR" || return 1

    bin/homestead "\$@"

    popd
}

. \$HOMESTEAD_DIR/aliases
EOF

popd
