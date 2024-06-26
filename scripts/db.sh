#!/usr/bin/bash -eux

set -o pipefail

# Install MariaDB
sudo apt-get update
# Install the required packages for the MariaDB repository
sudo apt-get install apt-transport-https curl

# Fetch the MariaDB key for the repository
sudo mkdir -p /etc/apt/keyrings
sudo curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

# Add the MariaDB repository to the sources list
sudo tee /etc/apt/sources.list.d/mariadb.sources <<EOF
# MariaDB 10.11 repository list - created 2024-04-04 08:24 UTC
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
# deb.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
URIs: https://deb.mariadb.org/10.11/ubuntu
# URIs: https://mariadb.gb.ssimn.org/repo/10.11/ubuntu
Suites: jammy
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

sudo apt-get update
# Install MariaDB
sudo apt-get install mariadb-server

TEMP_SQL_FILE=$(mktemp)

cat <<EOF | sudo tee "$TEMP_SQL_FILE"
-- Create the database and user for WordPress
CREATE DATABASE IF NOT EXISTS wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'wordpressuser'@'%' IDENTIFIED BY 'b0njour';
-- Grant the user all privileges on the WordPress database
GRANT ALL ON wordpress.* TO 'wordpressuser'@'%';
-- Flush the privileges to ensure they are saved and applied
FLUSH PRIVILEGES;
EOF

# shellcheck disable=SC2024
# Import the SQL file to run the commands
sudo mysql < "$TEMP_SQL_FILE" 
rm "$TEMP_SQL_FILE"

# Allow remote connections to the database
printf "[main]\n bind-address = 0.0.0.0" | sudo tee /etc/mysql/mariadb.conf.d/50-server.cnf