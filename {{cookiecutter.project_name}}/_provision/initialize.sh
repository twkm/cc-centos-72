#!/bin/bash
# Configure Apache to use our custom apache configs
# Remove Default SSL Virtual Host
# Add common aliases
# Setup syntax highlighted vim

yum -y -q install vim-enhanced
yum -y -q install mod_ssl openssl
# Install Apache
yum -y -q install httpd
yum -y -q install yum-utils
# Great tool for outputting folder structures
yum -y -q install tree
# Install PHP
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum -y -q install php56w php56w-opcache php56w-common php56w-xml php56w-mcrypt php56w-gd php56w-devel php56w-mysql php56w-intl php56w-mbstring php56w-bcmath php56w-pecl-imagick.x86_64
# Install MySQL
rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
yum-config-manager -q --disable mysql57-community
yum-config-manager -q --enable mysql56-community
yum -y -q install mysql-community-server
# Configure PHP.ini for Development
sed -i 's/display_errors = .*/display_errors = On/' /etc/php.ini
sed -i 's/error_reporting = .*/error_reporting = E_ALL/' /etc/php.ini
# Change which user runs apache
sed -i 's/User apache/User vagrant/' /etc/httpd/conf/httpd.conf
sed -i 's/Group apache/Group vagrant/' /etc/httpd/conf/httpd.conf
# Get rid of the Welcome configuration
printf '## REMOVED' > /etc/httpd/conf.d/welcome.conf
# Change access control on vhosts directories
printf "\n<Directory /srv/vhosts/*/data/>\n\tRequire all granted\n</Directory>\n\n" >> /etc/httpd/conf/httpd.conf
# Change ownership of folder PHP session files
chown root:vagrant /var/lib/php/session
# Remove SSL Default host from Apache config
sed -i '/^## SSL Virtual Host Context$/,$d' /etc/httpd/conf.d/ssl.conf
printf "## Removed default virtual host from this file with vagrant provision script" >> /etc/httpd/conf.d/ssl.conf
# Setup vhosts include folder - This folder contains symlinks to all our virtual host configuration files
mkdir /etc/httpd/vhosts.d
	## vhost configurations symlinked in separate Vagrant prcess
# Enable name based Virtual Hosts
sed -i 's/#NameVirtualHost \*:80/NameVirtualHost \*:80\nNameVirtualHost \*:443/' /etc/httpd/conf/httpd.conf
# Include symlink files from the vhosts.d containing folder
printf "\n#Include virtual host configurations\nInclude /etc/httpd/vhosts.d/*.conf\n" >> /etc/httpd/conf/httpd.conf
printf "\nMutex fcntl\n" >> /etc/httpd/conf/httpd.conf
# Add .bashrc settings
printf "\n#Custom aliases and environment variables added with vagrant provision script\nalias l='ls -lah'\nalias vi='vim'\nexport LANG='pposix'\n" >> /home/vagrant/.bashrc
# Setup MySQL Logging for help debugging
printf "\nlong_query_time=1" >> /etc/my.cnf
printf "\nlog-slow-queries=/srv/vhosts/${project_name}/logs/slow_queries_log" >> /etc/my.cnf
printf "\nlog-queries-not-using-indexes" >> /etc/my.cnf
service mysqld start
chkconfig --level 345 mysqld on
# Set root:root for dev environment
mysqladmin password root
	## Databases imported in separate Vagrant process
# Change Timezone
rm /etc/localtime
ln -s /usr/share/zoneinfo/America/Edmonton /etc/localtime
# Generate Self Signed SSL if it doesn't exist in the project yet
if [ ! -f /srv/vhosts/${project_name}/config/ssl/www.dev.crt ]; then
    openssl req \
        -new \
        -newkey rsa:4096 \
        -days 365 \
        -nodes \
        -x509 \
        -subj "/C=CA/ST=Denial/L=Calgary/O=Caliston Corp. Development/CN=${project_name}.dev" \
        -keyout /srv/vhosts/${project_name}/config/ssl/www.dev.key \
        -out /srv/vhosts/${project_name}/config/ssl/www.dev.crt
fi

systemctl start httpd.service
