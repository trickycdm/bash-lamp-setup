#!/bin/bash
#****************************************************************
#bash script to set up a basic Ubuntu/Debian LAMP stack stack including:
#Apache2
#PHP7 [php-curl, php-mysql, libapache2-mod-php, php-mcrypt]
#Git
#lets encrypt
#OPTIONALS:
#MySQL
#Wordpress and the WP-CLI tools
#Fail2Ban

#if you want to run this from a local to remote host use: ssh <your ssh config host> -t "$(<lamp_setup.sh)"

#Written by: Colin Mackenzie
#Updated: 4-8-16
#****************************************************************

#vars used to control optionals
wordpress=false;
fail2Ban=false;
mySql=false;
#colors
greenText="\e[32m";
redText="\e[31m";
defaultText="\e[39m";

function checkOsSupport {
  if [ "`lsb_release -is`" != "Ubuntu" ] && [ "`lsb_release -is`" != "Debian" ]
  then
    echo "${redText}Unsupported OS. This only works for Ubuntu/Debian!${defaultText}";
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
  sudo apt-get -y install php libapache2-mod-php php-mcrypt php-mysql php-curl;
  sudo chmod 755 -R /var/www/;
  sudo service apache2 restart;
  printf "${greenText}Apache2, PHP and installed.\n${defaultText}";
}
#install lets encrypt
function installLe {
  cd /;
  sudo git clone https://github.com/certbot/certbot;
}
function autoRenewCerts {
  printf "Want to auto renew your LE certs? Open crontab (crontab -e) and add this line. It will attempt a renewal every month."
  #echo new cron into cron file set certs to attemp auto update every month. Will only run if cert has < 30 left
  printf "\n${greenText}00 00 01 * * ~/certbot/certbot-auto renew --quiet --no-self-upgrade${defaultText}\n";
}
function checkForRoot {
  if [ "`whoami`" == "root" ];
  then
    printf "${redText}Looks like you are running as root! Do you want to set up a new user?\n
    WARNING! This will copy your current ssh public key into the authorized_keys of the
    new user. It is reccomended you have a backup of this key and an alternative means of
    accessing the server should an error occur during the write.\n\n${defaultText}"
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
  sudo apt-get install -y php-curl php-gd php-mbstring php-mcrypt php-xml php-xmlrpc;
  sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar;
  sudo chmod +x wp-cli.phar;
  sudo mv wp-cli.phar /usr/local/bin/wp;
  read -p "Enter full dir path for Wordpress install: " wpDir;
  sudo mkdir $wpDir;
  sudo chown -R www-data:www-data $wpDir;
  cd $wpDir;
  wp core download --allow-root;
  printf "${greenText}Wordpress & CLI tools installed in $wpDir. You can check the CLI tools with wp --info.\n${defaultText}";
}
function installFail2ban {
  sudo apt-get -y install fail2ban;
  sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local;
  printf "${greenText}Fail2Ban installed.\n${defaultText}";
}
#!/bin/bash
function setUpVhost {
  sitesEnable='/etc/apache2/sites-enabled/';
  sitesAvailable='/etc/apache2/sites-available/';
  printf "${greenText}Begin Vhost Setup\n${defaultText}";
  read -p "Server admin email: " email;
  read -p "Domain root name (do NOT add www): " domain;
  read -p "Enter full doc root path: " docRoot;
  #make sure this doc root exists
  if [ ! -d "$docRoot" ]
  then
    sudo mkdir $docRoot;
    sudo chown -R www-data:www-data $docRoot;
    sudo chmod 755 $docRoot;
  fi
  newSiteConf="$sitesAvailable$domain.conf";
  printf "
  <VirtualHost *:80>
			ServerAdmin $email
			ServerName $domain
			DocumentRoot $docRoot
			<Directory />
				AllowOverride All
			</Directory>
			<Directory $docRoot>
				Options -Indexes +FollowSymLinks +MultiViews
				AllowOverride all
				Require all granted
			</Directory>
			ErrorLog /var/log/apache2/$domain-error.log
			LogLevel error
			CustomLog /var/log/apache2/$domain-access.log combined
	</VirtualHost>

    " > $newSiteConf;
    sudo a2ensite $domain;
    sudo service apache2 restart;
    printf "New vHost created. Your doc root is $docRoot. Custom error logs have been added to /var/log/apache2.\n\n";
}
function runOptionalInstall {
  if $mySql
  then
      sudo apt-get -y install mysql-server;
      sudo mysql_install_db
      sudo /usr/bin/mysql_secure_installation
      printf "${greenText}MySQL Installed. Please run secure install. \"mysql_secure_installation\"\n${defaultText}";
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

printf "\n${greenText}You are about to install an a complete LAMP stack. Ensure you are doing this on a new, clean server.
\nContinue? (Use numeric selections)\n${defaultText}";
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
