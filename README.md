# :racehorse: bashfy

A collection of Bash scripts designed to streamline local setups on Linux

## wpsetup.sh

This automation streamlines repetitive **WordPress** setup tasks by downloading the latest WordPress version, configuring Apache virtual hosts, and creating a MySQL database with minimal manual input. Create a ``databases`` directory and add an SQL file named after the website to enable automatic database import. If the SQL file is not present, the script will create an empty database.

### Usage

```
sudo bash wpsetup.sh
```

### :hammer: Next Steps

- Automatically generate and configure .htaccess
