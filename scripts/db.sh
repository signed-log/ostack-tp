#!/usr/bin/bash -eux

set -o pipefail

# Install MariaDB
sudo apt-get install apt-transport-https curl
sudo mkdir -p /etc/apt/keyrings
sudo curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

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
sudo apt-get install mariadb-server

TEMP_SQL_FILE=$(mktemp)

cat <<EOF > "$TEMP_SQL_FILE"
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
CREATE USER 'wordpressuser'@'%' IDENTIFIED WITH mysql_native_password BY 'b0njour';
GRANT ALL ON wordpress.* TO 'wordpressuser'@'%';
FLUSH PRIVILEGES;
EOF

# shellcheck disable=SC2024
sudo mysql < "$TEMP_SQL_FILE" 
rm "$TEMP_SQL_FILE"