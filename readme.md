# Bash LAMP setup
This bash script will allow you to quickly get a full LAMP stack set up on Ubuntu/Debian on a remote host by running 1 command from your local machine.

It is recommended to run this script on a new clean server.

It will install:
* Apache2
* PHP7 [php-curl, php-mysql, libapache2-mod-php, php-mcrypt]
* Git
* Let's Encrypt

Optionals:
* MySQL
* Fail2Ban
* Wordpress and the CLI tools
* Create a non root user
* Create a vHost

It will set all the permissions to the Apache user. These are only base permissions. You can change them manually if you like.
# Usage
Grab the lamp_setup.sh script save it somewhere locally then run:

```
ssh <your ssh config host> -t "$(<lamp_setup.sh)"
```

Where *your ssh config host* is either the hostname from your ssh config file OR a normal ssh connection command i.e name@host.

This will create the ssh connection and run the setup. 95% is automated but you will be prompted for the optionals and vHost setup. It should take around 3-4 minutes to complete.
# TLS setup
This uses Let's Encrypt to automate the TLS setup. In order for this to work your domain must be resolving to the server you are setting up. It will also offer the cron job Details
setting up the auto renewal.
