#!/bin/sh

#### Installation of WHMCS 8.8.0 on Ubuntu 20.04 64 bit #####

#### Pre-requisites ####
##  Apache version 2.4
##  Mariadb server 10.8
##  PHP version 8.1
##  ionCube Loader 13.0.2
##  WHMCS version 8.8.0 
##  An active, funded Vultr Account
##  A valid Vultr API Key

#### Perform full system Update ####
sudo apt update -y && sudo apt upgrade -y
sudo apt install ca-certificates apt-transport-https software-properties-common -y

#### Installation of other packages ####
sudo apt install -y wget git unzip gnupg iptables-dev iptables-persistent 

cd /usr/src
sudo cat <<EOF > firewall.sh

iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 1101 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP
EOF

iptables-save > /etc/iptables/rules.v4

sudo chmod 755 firewall.sh
sudo ./firewall.sh

# Set Kigali Timezone
timedatectl set-timezone Africa/Kigali
timedatectl

################ Start of LAMP installation #################

#### Installation of apache 2.4 ####
sudo apt install -y apache2
sudo systemctl enable apache2 
sudo systemctl restart apache2

# Enabling mod_rewrite
sudo a2enmod rewrite
sudo a2enmod php*
sudo systemctl restart apache2 

cd /etc/apache2/sites-available
sudo cp 000-default.conf billing.conf

sudo nano billing.conf

    <VirtualHost *:80>
    . . .
    ServerName billing.example.com
    DocumentRoot /var/www/html
    . . .
   </VirtualHost>

sudo a2ensite billing.conf

sudo systemctl reload apache2
sudo systemctl restart apache2

sudo nano /etc/apache2/apache2.conf

    . . .
       ServerTokens Prod
       ServerSignature Off 
       ServerName localhost
     . . .

sudo systemctl restart apache2
apache2ctl configtest

rm /var/www/html/index.html

###### Install letsencrypt ssl certificate #########
sudo apt -y install certbot python-certbot-apache
sudo certbot --apache

##### Installation of Mariadb in ubuntu 20.04 #######
cd /usr/src
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] https://mariadb.mirror.liquidtelecom.com/repo/10.8/ubuntu focal main'
sudo apt update

sudo apt apt -y install mariadb-server mariadb-client
sudo systemctl restart mariadb.service
sudo systemctl enable mariadb.service 

# Securing MySQL
# mysql_secure_installation

sudo mysql -u root -p << MYSQL_SCRIPT
CREATE DATABASE whmcs;
GRANT ALL ON whmcs.* TO whmcs@localhost IDENTIFIED BY "StrongDBPassw0rd";
FLUSH PRIVILEGES;
EXIT;
MYSQL_SCRIPT

######## Installation of php 8.1 #################
sudo add-apt-repository ppa:ondrej/php  -y
sudo apt update

sudo apt install -y php8.1 php8.1-common php8.1-cli php8.1-bz2 php8.1-json php8.1-iconv php8.1-mysql php8.1-zip php8.1-gd php8.1-gmp php8.1-intl \
php8.1-bcmath php8.1-mbstring php8.1-curl php8.1-xml php8.1-imap libapache2-mod-php8.1 php8.1-xmlrpc php8.1-soap php8.1-ldap php8.1-cgi php8.1-opcache php-pear 

dpkg --list | grep php
# php -version

################ End of LAMP installation #################

###### Installation of mod security and configuration #################

sudo apt install -y libapache2-mod-security2
a2enmod security2

apachectl -M | grep security

sudo mv /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
sudo nano /etc/modsecurity/modsecurity.conf

          # change detectiononly to on
          SecRuleEngine on
          SecResponseBodyAccess Off

sudo service apache2 restart
sudo rm -rf /usr/share/modsecurity-crs
sudo git clone https://github.com/SpiderLabs/owasp-modsecurity-crs.git /usr/share/modsecurity-crs
cd /usr/share/modsecurity-crs 
sudo mv crs-setup.conf.example crs-setup.conf
sudo nano /etc/apache2/mods-enabled/security2.conf

        # Change all content to look like this
        <IfModule security2_module> 
                SecDataDir /var/cache/modsecurity 
                IncludeOptional /etc/modsecurity/*.conf 
                IncludeOptional /usr/share/modsecurity-crs/*.conf 
                IncludeOptional /usr/share/modsecurity-crs/rules/*.conf 
        </IfModule>

sudo systemctl restart apache2 
sudo apache2ctl -t && sudo apache2ctl restart

###### End of mod security configuration #################

###### Installation of Ioncube loader ###################

cd /usr/src
sudo wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
sudo tar xvfz ioncube_loaders_lin_x86-64.tar.gz
ls ioncube/*

# find extension directory
php -i | grep extension_dir

sudo cp ioncube/ioncube_loader_lin_8.1.so /usr/lib/php/20190902/
echo "zend_extension=/usr/lib/php/20190902/ioncube_loader_lin_8.1.so"|sudo tee -a /etc/php/8.1/cli/php.ini
echo "zend_extension=/usr/lib/php/20190902/ioncube_loader_lin_8.1.so"|sudo tee -a /etc/php/8.1/apache2/php.ini

sudo systemctl restart apache2.service
php -v

#### Installation of WHMCS 8.8.0 ####

cd /usr/src
wget https://downloads.whmcs.com/whmcs_v880_full.zip
unzip whmcs_v771_full.zip

cp -rf /usr/src/whmcs/* /var/www/html/
cd /var/www/html/

cp configuration.php.new configuration.php && chmod 777 configuration.php

vim configuration.php

         # add this line at bottom
         $customadminpath = '256admin';
         $templates_compiledir = "/usr/local/src/templates_c/";
         $attachments_dir = "/usr/local/src/attachments/";
         $downloads_dir = "/usr/local/src/downloads/";
         $crons_dir = "/usr/local/src/crons/";
         $whmcspath = "/usr/local/src/";

mv /var/www/html/templates_c /usr/local/src/ && chmod 777 /usr/local/src/templates_c
mv /var/www/html/attachments /usr/local/src && chmod 777 /usr/local/src/attachments
mv /var/www/html/downloads /usr/local/src && chmod 777 /usr/local/src/downloads
mv /var/www/html/crons /usr/local/src && ls /usr/local/src/crons
mkdir /usr/local/src/whmcs_updates && chmod 777 /usr/local/src/whmcs_updates

cp config.php.new config.php

         $crons_dir = '/var/www/html/';

vim /var/www/html/.htaccess 
chmod 777 /var/www/html/.htaccess

https://billing.vps.rw/install/install.php

# Register whmcs
WHMCS-66e4f7566d5841a6ce07
admin username: admin 
password: password

# After installation remove install folder
cd /var/www/html/
rm -rf install/

chmod 444 /var/www/html/configuration.php

# Rename admin folder for security purposes
cd /var/www/html/
cp -rf admin 256admin
rm -rf admin

# change whmcs logo
/var/www/html/assets/img/whmcs.png

# Upload Direct Payonline module
cd /usr/src
git clone https://github.com/DirectPay-Online/DPO_WHMCS.git
cp -rf DPO_WHMCS/modules/gateways/* /var/www/html/modules/gateways/

# Downloadload Vultr module
cd /usr/src
git clone https://github.com/vultr/whmcs-vultr
ls whmcs-vultr

cp -rf /usr/src/whmcs-vultr/addons/* /var/www/html/modules/addons
cp -rf /usr/src/whmcs-vultr/servers/* /var/www/html/modules/servers

# Configure WHMCS
# https://billing.vps.rw

# Renew certbot certificate
crontab -e

0 0 */45 * * certbot renew --dry-run
*/5 * * * * /usr/bin/php -q /usr/local/src/crons/cron.php
*/5 * * * * /usr/bin/php -q /usr/local/src/crons/pop.php

# Run this to test the cron jobs
/usr/bin/php -q /usr/local/src/crons/cron.php
