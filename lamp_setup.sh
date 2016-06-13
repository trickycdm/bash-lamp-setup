#!/bin/bash
#****************************************************************
#bash script to set up a basic Ubuntu/Debian LAMP stack stack including:
#Apache2
#PHP5 [php5-curl, php5-mysql, libapache2-mod-php5, php5-mcrypt]
#Git
#lets encrypt
#OPTIONALS:
#MySQL
#Wordpress and the WP-CLI tools
#Fail2Ban

#Note the use of sudo, you should never be running this script as root!
#if you want to run this from a local to remote host use: ssh <your ssh config host> -t "$(<lamp_setup.sh)"

#Written by: Colin Mackenzie
#Updated: 6-6-16
#****************************************************************

#vars used to control optionals
wordpress=false;
fail2Ban=false;
mySql=false;
function checkOsSupport {
  if [ "`lsb_release -is`" != "Ubuntu" ] && [ "`lsb_release -is`" != "Debian" ]
  then
    echo "\e[31mUnsupported OS. This only works for Ubuntu/Debian!\e[39m";
    exit;
  fi
}
function setOptionals {
    printf "Do you need MySQL?\n"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) mySql=true; break;;
            No ) mySql=false; break;;
        esac
    done
    printf "Do you need Wordpress & the CLI tools?\n"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) wordpress=true; break;;
            No ) wordpress=false; break;;
        esac
    done
    printf "Do you need Fail2Ban?\n"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) fail2Ban=true; break;;
            No ) fail2Ban=false; break;;
        esac
    done
    printf "Do you need to set up a vHost?\n"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) vHost=true; break;;
            No ) vHost=false; break;;
        esac
    done
}
function setUpDefaults {
  sudo apt-get update;
}
function installLap {
  sudo apt-get -y install apache2;
  sudo apt-get -y install php5 libapache2-mod-php5 php5-mcrypt php5-mysql php5-curl;
  sudo chmod 755 -R /var/www/;
  sudo printf "<?php\nphpinfo();\n?>" > /var/www/html/info.php;
  sudo service apache2 restart;
  sudo apt-get -y install git;
  printf "\e[32mApache2, PHP5, Git and installed. An info.php file has been created in you webroot (/var/www/html/info.php)\n\e[39m";
}
#install lets encrypt
function installLe {
  cd /;
  sudo git clone https://github.com/certbot/certbot;
}
function checkForRoot {
  if [ "`whoami`" == "root" ];
  then
    printf "\e[31mLooks like you are running as root! Do you want to set up a new user?\n
    WARNING! This will copy your current ssh public key into the authorized_keys of the
    new user. It is reccomended you have a backup of this key and an alternative means of
    accessing the server should an error occur during the write.\n\n\e[39m"
      select yn in "Yes" "No"; do
          case $yn in
              Yes ) createNewUser; break;;
              No ) break;;
          esac
      done
  fi
}
function createNewUser {
  read -p "User name: " username;
  adduser $username;
  gpasswd -a $username sudo;
  rootKey=$(<~/.ssh/authorized_keys);
  if [ ! -d "/home/$username/.ssh" ]
  then
    sudo mkdir /home/$username/.ssh;
    sudo chmod 700 /home/$username/.ssh;
  fi
  cd /home/$username/.ssh;
  touch authorized_keys;
  echo $rootKey >> authorized_keys;
  chown -R $username:$username /home/$username/.ssh;
  chmod 600 authorized_keys;
}
function installWordpress {
  #install the Apache2 mod rewrite module to allow Wordpress to use htaccess
  sudo a2enmod rewrite;
  sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar;
  sudo chmod +x wp-cli.phar;
  sudo mv wp-cli.phar /usr/local/bin/wp;
  read -p "Enter full dir path for Wordpress install: " wpDir;
  sudo mkdir $wpDir;
  sudo chown -R $USER:www-data $wpDir;
  cd $wpDir;
  wp core download --allow-root;
  printf "\e[32mWordpress & CLI tools installed in $wpDir. You can check the CLI tools with wp --info.\n\e[39m";
}
function installFail2ban {
  sudo apt-get -y install fail2ban;
  sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local;
  printf "\e[32mFail2Ban installed.\n\e[39m";
}
#!/bin/bash
function setUpVhost {
  sitesEnable='/etc/apache2/sites-enabled/';
  sitesAvailable='/etc/apache2/sites-available/';
  printf "\e[32mBegin Vhost Setup\n\e[39m";
  read -p "Server admin email: " email;
  read -p "Domain root name (do NOT add www): " domain;
  read -p "Enter full doc root path: " docRoot;
  #make sure this doc root exists
  if [ ! -d "$docRoot" ]
  then
    sudo mkdir $docRoot;
    sudo chown -R $USER:www-data $docRoot;
    sudo chmod 755 $docRoot;
  fi
  newSiteConf="$sitesAvailable$domain.conf";
  printf "<VirtualHost *:80>
			ServerAdmin $email
			ServerName $domain
			DocumentRoot $docRoot
			<Directory />
				AllowOverride All
			</Directory>
			<Directory $docRoot>
				Options Indexes FollowSymLinks MultiViews
				AllowOverride all
				Require all granted
			</Directory>
			ErrorLog /var/log/apache2/$domain-error.log
			LogLevel error
			CustomLog /var/log/apache2/$domain-access.log combined
		</VirtualHost>" > $newSiteConf;
    sudo a2ensite $domain;
    sudo service apache2 restart;
    printf "New vHost created. Your doc root is $docRoot. Custom error logs have been added to /var/log/apache2.\n\n";
}
function runOptionalInstall {
  if $mySql
  then
      sudo apt-get -y install mysql-server libapache2-mod-auth-mysql;
      sudo mysql_install_db
      sudo /usr/bin/mysql_secure_installation
      printf "\e[32mMySQL Installed. Please run secure install. \"mysql_secure_installation\"\n\e[39m";
  fi
  if $wordpress
  then
      installWordpress;
  fi
  if $fail2Ban
  then
      installFail2ban;
  fi
  if $vHost
  then
      setUpVhost;
  fi
}

printf "\nYou are about to install an a complete LAMP stack. Ensure you are doing this on a new, clean server.
\nContinue? (Use numeric selections)\n";
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done
checkOsSupport;
setOptionals;
setUpDefaults;
installLap;
installLe;
checkForRoot;
runOptionalInstall;
