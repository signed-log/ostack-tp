#!/usr/bin/bash -eux

set -o pipefail

export DB_IP="<PUT FLOATING HERE>"
export DB_PORT="3306"
export DEBIAN_FRONTEND=noninteractive

# Update the package list
sudo apt-get update

# Install dependencies
sudo apt-get install -y ca-certificates \
  apt-transport-https \
  software-properties-common \
  lsb-release

# Use the Ondřej Surý repository to install the latest versions of Apache and PHP
sudo add-apt-repository ppa:ondrej/php -y
sudo add-apt-repository ppa:ondrej/apache2 -y

# Install Apache and PHP including the required modules
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

# Start and enable the Apache service
sudo systemctl enable --now apache2

# Create web server directory
sudo mkdir -p /srv/www
# Give permissions to the web server user
sudo chown www-data: /srv/www
# Download the latest version of WordPress and extract it to the web server directory
curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www

# Create the Apache configuration file for WordPress
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
# Enable Wordpress site
sudo a2ensite wordpress
# Remove default website
sudo a2dissite 000-default
# Enable rewrite module
sudo a2enmod rewrite

# Copy the sample configuration file to the correct location
sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
# Update the configuration file with the database details
sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/wordpressuser/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/password_here/b0njour/' /srv/www/wordpress/wp-config.php
# Update the database host to the IP address of the database server
sudo -u www-data sed -i 's/localhost/'"$DB_IP:$DB_PORT"'/' /srv/www/wordpress/wp-config.php

# Needs manual setting up the secret keys in the wp-config.php file using https://api.wordpress.org/secret-key/1.1/salt/

sudo systemctl restart apache2