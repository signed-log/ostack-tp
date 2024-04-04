#!/usr/bin/bash -eux

set -o pipefail

export DB_IP="<PUT FLOATING HERE>"
export DEBIAN_FRONTEND=noninteractive

# Install Apache
sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install -y ca-certificates apt-transport-https software-properties-common lsb-release

sudo add-apt-repository ppa:ondrej/php -y
sudo add-apt-repostiory ppa:ondrej/apache2 -y

sudo apt-get install -y apache2 \
  php8.3-common \
  php8.3-mysql \
  php8.3-curl \
  libapache2-mod-php8.3 \
  php8.3-mbstring \
  php8.3-xml \
  php8.3-zip \
  php8.3-gd \
  php8.3-soap \
  php8.3-ssh2 \
  php8.3-tokenizer \
  php8.3-intl \
  php8.3-xml \
  php8.3-xmlrpc


sudo systemctl enable --now apache2
sudo systemctl restart apache2

sudo apache2ctl configtest
sudo systemctl restart apache2

sudo mkdir -p /srv/www
sudo chown www-data: /srv/www
curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www

cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF
sudo a2ensite wordpress
sudo a2enmod rewrite

sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/wordpressuser/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/password_here/b0njour/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/localhost/'"$DB_IP"'/' /srv/www/wordpress/wp-config.php

sudo systemctl restart apache2