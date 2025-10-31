#!/bin/bash

# initial configs
read -p "Enter the website name (ex: amazingproject): " websitename
read -p "Enter the GitHub URL: " githuburl
read -p "Enter the MySQL root username : " mysql_user

## WORDPRESS CONFIGS
cd /var/www/ || exit

# clone the repository if provided
if [ -n "$githuburl" ]; then
  git clone "$githuburl" "$websitename" || { echo "Something went wrong. Please, check the GitHub URL and try again."; }
else
  echo "No GitHub URL provided. Procceding with a new WordPress installation."
fi

cd "$websitename"

# download and extract latest WordPress
wget https://wordpress.org/latest.tar.gz -O /tmp/latest.tar.gz
tar -xzf /tmp/latest.tar.gz -C /tmp/
rm /tmp/latest.tar.gz
rsync -av /tmp/wordpress/ . --exclude=wp-config.php
rm -rf /tmp/wordpress

## MYSQL CONFIGS
echo "Setting up MySQL database"
sudo mysql -u "${mysql_user}" -e "CREATE DATABASE ${websitename} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

cd ~
sql_file="databases/${websitename}.sql"
gz_file="${sql_file}.gz"
message="Importing SQL file. Please wait, this may take a while..."

if [ -f "$gz_file" ]; then
  echo "$message"
  zcat "${gz_file}" | sudo mysql -u "${mysql_user}" "${websitename}"
elif [ -f "$sql_file" ]; then
  echo "$message"
  sudo mysql -u "${mysql_user}" "${websitename}" < "${sql_file}"
else
  echo "No sql file found."
fi

## APACHE CONFIGS
echo "Creating Apache config for $websitename..."
config_path="/etc/apache2/sites-available/${websitename}.conf"

sudo bash -c "cat > '$config_path' <<EOF
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
sudo a2ensite "${websitename}.conf"
sudo systemctl reload apache2
echo "website available on http://${websitename}.local"