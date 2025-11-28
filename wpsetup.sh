#!/bin/bash

# colors
RED='\e[31m'
BLU='\e[34m'
GRN='\e[32m'
DEF='\e[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error:${DEF} This script must be executed with elevated privileges (sudo)."
  echo -e "${BLU}Usage${DEF}: sudo bash ./wpsetup.sh"
  exit 1
fi

echo -e "${GRN}✔ Running in sudo mode...${DEF}"

# website name
while true; do
  read -p "Enter the website name (max 20 chars): " websitename

  # lowercase and sanitize
  websitename=$(echo "$websitename" | tr '[:upper:]' '[:lower:]')
  cleanedname=$(echo "$websitename" | sed 's/[^a-z0-9]//g')

  # empty name
  if [ -z "$cleanedname" ]; then
    echo -e "${RED}Error:${DEF} The project name cannot be empty."
    continue
  fi

  # name too long
  if [ ${#cleanedname} -gt 20 ]; then
    echo -e "${RED}Error:${DEF} The project name is too long (max 20 chars)."
    continue
  fi
  websitename="$cleanedname"
  break
done

# clone repository
cd /var/www/ || exit
mkdir "$websitename"

while true; do
  read -p "Please enter the repository URL (or leave empty for a new WordPress installation): " repositoryurl

  if [ -z "$repositoryurl" ]; then
    echo -e "${BLU}Info:${DEF} No repository URL provided. Proceeding with a fresh WordPress installation."
    break
  fi

  git clone "$repositoryurl" "$websitename"
  if [ $? -eq 0 ]; then
    echo -e "${GRN}Repository cloned successfully!${DEF}"
    break
  else
    echo -e "${RED}Error:${DEF} Invalid repository URL."
  fi
done

cd "$websitename"

# download and extract latest WordPress
echo -e "${BLU}Downloading the latest WordPress version...${DEF}"
wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
tar -xzf /tmp/latest.tar.gz -C /tmp/
rm /tmp/latest.tar.gz
rsync -av /tmp/wordpress/ .
rm -rf wp-content/themes/twenty*

if [ ! -f wp-config.php ]; then
  cp wp-config-sample.php wp-config.php
fi

sed -i "s/database_name_here/${websitename}/" wp-config.php

# clean up temporary files
rm -rf /tmp/wordpress

clear
echo -e "${GRN}WordPress dependencies successfully installed! ✔${DEF}"

## MySQL configs
echo -e "${BLU}Creating MySQL database...${DEF}"
mysql -u -e "CREATE DATABASE ${websitename} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

cd ~
sql_file="databases/${websitename}.sql"
gz_file="${sql_file}.gz"
message="${BLU}Importing SQL file. Please wait, this may take a while...${DEF}"

if [ -f "$gz_file" ]; then
  echo -e "$message"
  zcat "${gz_file}" | mysql -u "${websitename}"
elif [ -f "$sql_file" ]; then
  echo -e "$message"
  mysql -u "${websitename}" < "${sql_file}"
else
  echo -e "${BLU}No SQL file to import. Proceding with empty database...${DEF}"
fi

## Apache configs
echo -e "${BLU}Creating Apache config for ${websitename}...${DEF}"
config_path="/etc/apache2/sites-available/${websitename}.conf"

bash -c "cat > '$config_path' <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/${websitename}
    ServerName ${websitename}.local

    <Directory /var/www/${websitename}>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>

    <Directory /var/www/${websitename}/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOF
"

# enable site and reload Apache
a2ensite "${websitename}.conf"
systemctl reload apache2

clear
echo -e "${GRN}Done!${DEF}"
echo -e "Your website is available on ${BLU}http://${websitename}.local${DEF} ✔"