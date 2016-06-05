#!/bin/bash
#****************************************************************
#bash script to set up a basic Ubuntu/Debian LAMP stack stack including:
#Apache2
#PHP5 [php5-curl, php5-mysql, libapache2-mod-php5, php5-mcrypt]
#Git
#lets encrypt
#OPTIONALS:
#MySQL
#WP-CLI (if using wordpress)
#Fail2Ban

#Note the use of sudo, you should never be running this script as root!
#if you want to run this from a local to remote host use: ssh <your ssh config host> -t "$(<lamp_setup.sh)"

#Written by: Colin Mackenzie
#Updated: 4-6-16
#****************************************************************

#Envars used to control optionals
WORDPRESS=false;
FAIL2BAN=false;
MYSQL=false;

function serverSetup {
  if [ "`lsb_release -is`" == "Ubuntu" ] || [ "`lsb_release -is`" == "Debian" ]
  then
      printf "Do you need MySQL?\n"
      select yn in "Yes" "No"; do
          case $yn in
              Yes ) MYSQL=true; break;;
              No ) MYSQL=false; break;;
          esac
      done
      printf "Do you need Wordpress & the CLI tools?\n"
      select yn in "Yes" "No"; do
          case $yn in
              Yes ) WORDPRESS=true; break;;
              No ) WORDPRESS=false; break;;
          esac
      done
      printf "Do you need Fail2Ban?\n"
      select yn in "Yes" "No"; do
          case $yn in
              Yes ) FAIL2BAN=true; break;;
              No ) FAIL2BAN=false; break;;
          esac
      done
      sudo apt-get update;
      sudo apt-get -y install apache2;
      sudo apt-get -y install php5 libapache2-mod-php5 php5-mcrypt php5-mysql php5-curl;
      sudo chmod 755 -R /var/www/;
      sudo printf "<?php\nphpinfo();\n?>" > /var/www/html/info.php;
      sudo service apache2 restart;
      sudo apt-get -y install git;
      #install lets encrypt
      cd /;
      sudo git clone https://github.com/certbot/certbot;
      printf "\e[32mApache2, PHP5, Git and Let's Encrypt installed. An info.php file has been created in you webroot (/var/www/html/info.php)\n\e[39m";
      if $MYSQL
      then
          sudo apt-get -y install mysql-server libapache2-mod-auth-mysql;
          #NOTE you will need to set up the secure db install after this manually
          #sudo mysql_install_db
          #sudo /usr/bin/mysql_secure_installation
          #.....
          printf "\e[32mMySQL Installed. Please run secure install. \"mysql_secure_installation\"\n\e[39m";
      fi
      if $WORDPRESS
      then
          sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar;
          sudo chmod +x wp-cli.phar;
          sudo mv wp-cli.phar /usr/local/bin/wp;
          printf "Enter dir name for WP install (advise using root domin name):\n";
          read WPDIR;
          cd /var/www/html;
          sudo mkdir $WPDIR;
          sudo chown -R www-data:www-data $WPDIR;
          cd $WPDIR;
          wp core download --allow-root;
          printf "\e[32mWordpress & CLI tools installed\n\e[39m";
      fi
      if $FAIL2BAN
      then
          sudo apt-get -y install fail2ban;
          sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local;
          printf "\e[32mFail2Ban installed\n\e[39m";
      fi
      printf "Do you want to set up a vHost?\n"
      select yn in "Yes" "No"; do
          case $yn in
              Yes ) vHost=true; break;;
              No ) vHost=false; break;;
          esac
      done
      if $vHost
      then
          setUpVhost;
      fi
  else
      printf "\e[31mUnsupported Operating System\n\e[39m";
  fi
}
#this will obviously only work for Apache. You will also need to set up the directory once this is created.
#if you installed wordpress the dir has already been created so use that.
function setUpVhost {
  sitesEnable='/etc/apache2/sites-enabled/';
  sitesAvailable='/etc/apache2/sites-available/';
  read -p "Server admin email:" email;
  read -p "Domain root name (do NOT add www):" domain;
  docRoot="/var/www/html/$domain";
  #make sure this doc root exists
  if [ ! -d "$docRoot" ]
  then
    sudo mkdir $docRoot;
    sudo chown -R www-data:www-data $docRoot;
  fi
  newSiteConf="$sitesAvailable$domain.conf";
  printf "<VirtualHost *:80>
			ServerAdmin $email
			ServerName $domain
			ServerAlias www.$domain
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
    printf "Do you want to set up TLS for this domain (you must already have DNS set up)?\n"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) cd /certbot; ./certbot-auto; break;;
            No ) exit; break;;
        esac
    done
}

printf "We are about to install an a complete LAMP stack. Ensure you are doing this on a new, clean server.\nContinue? (Use numeric selections)\n"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) serverSetup; break;;
        No ) exit;;
    esac
done
