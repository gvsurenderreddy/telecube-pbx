#!/bin/sh

#
# This is the PBX installer script
# Only supports Ubuntu version(s) 14.04
# It will install the required packages and configure the server
# 

# Make sure only root can run this script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
#

# test the os and version
. /etc/os-release
if [ "$NAME" != "Ubuntu" ] || [ "$VERSION_ID" != "14.04" ]; then
    echo "Sorry, this script only supports Ubuntu version 14.04"
    echo "You are on: $NAME $VERSION_ID"
    exit 1
fi


if !(whiptail --title "Telecube PBX Install" --yesno "This script will install the Telecube PBX, do you want to continue?" 10 60) then
    echo "Bye."
    exit 1
fi

# we have to make sure mysql, asterisk and nginx aren't already installed
ASTERISK_INSTALLED="$(dpkg-query -l | grep asterisk | wc -l)"
if [ "$ASTERISK_INSTALLED" != "0" ]; then
	echo "Asterisk is already installed!"
	echo "To continue you must remove it: apt-get remove -y asterisk && apt-get purge && apt-get autoremove -y"
	exit 1
fi
MYSQL_INSTALLED="$(dpkg-query -l | grep mysql-server | wc -l)"
if [ "$MYSQL_INSTALLED" != "0" ]; then
	echo "Mysql is already installed!"
	echo "To continue you must remove it: apt-get remove -y mysql-server && apt-get purge && apt-get autoremove -y"
	exit 1
fi
NGINX_INSTALLED="$(dpkg-query -l | grep nginx | wc -l)"
if [ "$NGINX_INSTALLED" != "0" ]; then
	echo "Nginx is already installed!"
	echo "To continue you must remove it: apt-get remove -y nginx && apt-get purge && apt-get autoremove -y"
	exit 1
fi

if [ ! -f /etc/apt/sources.list.d/nginx-stable.list ]; then
	echo "deb http://ppa.launchpad.net/nginx/stable/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/nginx-stable.list 
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C 
fi

x=0
while true ; do
	if debconf-apt-progress -- aptitude -y update
		then 
			echo "done .."
			break
		else 
			echo "oops, trying again in a few seconds .."
			sleep 3
	fi
	
	x=$((x+1))
	if ["$x" = 30] ; then 
		echo "\n\n## ERROR! ##\nFailed to update!\n## ## ##\n"
		break 
	fi	
done


x=0
while true ; do

	if debconf-apt-progress -- aptitude -y install asterisk asterisk-dahdi asterisk-mysql asterisk-core-sounds-en-wav asterisk-moh-opsound-wav nginx php5 php5-fpm php5-mysql php5-curl git rsync
		then 
			echo "done .."
			break
		else 
			echo "oops, trying again in a few seconds .."
			sleep 3
	fi
	
	x=$((x+1))
	if ["$x" = 30] ; then 
		echo "\n\n## ERROR! ##\nFailed to install some critical packages!\n## ## ##\n"
		break 
	fi	
done

# generate a random 16 char str for mysql password
mysql_root_pass=$(openssl rand -base64 16)

x=0
while true ; do

	echo mysql-server mysql-server/root_password password $mysql_root_pass | sudo debconf-set-selections
	echo mysql-server mysql-server/root_password_again password $mysql_root_pass | sudo debconf-set-selections

	if debconf-apt-progress -- aptitude -y install mysql-server
		then 
			echo "done .."
			break
		else 
			echo "oops, trying again in a few seconds .."
			sleep 3
	fi
	
	x=$((x+1))
	if ["$x" = 30] ; then 
		echo "\n\n## ERROR! ##\nFailed to install some critical packages!\n## ## ##\n"
		break 
	fi	
done


# write the password to the config file in /opt so the control panel has access to the db
echo "<?php\n\$mysql_root_pass = \"$mysql_root_pass\";\n?>" > /opt/base_config.inc.php

# create the db and initial tables/values
mysql -u root -p"$mysql_root_pass" -e "create database telecube;"
mysql -u root -p"$mysql_root_pass" -e "CREATE TABLE telecube.preferences (name varchar(254), value varchar(254));"

mysql -u root -p"$mysql_root_pass" -e "insert into telecube.preferences (name, value) values ('pbx_login_username', 'admin');"
mysql -u root -p"$mysql_root_pass" -e "insert into telecube.preferences (name, value) values ('pbx_login_password', 'admin');"

mysql -u root -p"$mysql_root_pass" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$mysql_root_pass" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$mysql_root_pass" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"$mysql_root_pass" -e "FLUSH PRIVILEGES"

mysql -u root -p"$mysql_root_pass" -e "CREATE TABLE IF NOT EXISTS telecube.sip_devices (
id int(11) NOT NULL,
\`name\` varchar(80) NOT NULL DEFAULT '',
\`context\` varchar(80) DEFAULT NULL,
callingpres enum('allowed_not_screened','allowed_passed_screen','allowed_failed_screen','allowed','prohib_not_screened','prohib_passed_screen','prohib_failed_screen','prohib','unavailable') DEFAULT 'allowed_not_screened',
deny text,
permit text,
secret varchar(80) DEFAULT NULL,
md5secret varchar(80) DEFAULT NULL,
remotesecret varchar(250) DEFAULT NULL,
transport enum('tcp','udp','tcp,udp') DEFAULT NULL,
\`host\` varchar(31) NOT NULL DEFAULT '',
nat varchar(32) NOT NULL DEFAULT 'no',
\`type\` enum('user','peer','friend') NOT NULL DEFAULT 'friend',
\`call-limit\` int(10) unsigned NOT NULL,
accountcode varchar(20) DEFAULT NULL,
amaflags varchar(13) DEFAULT NULL,
def_ac varchar(6) NOT NULL,
callgroup varchar(10) DEFAULT NULL,
callerid varchar(80) DEFAULT NULL,
defaultip varchar(15) DEFAULT NULL,
dtmfmode varchar(7) DEFAULT NULL,
fromuser varchar(80) DEFAULT NULL,
fromdomain varchar(80) DEFAULT NULL,
insecure varchar(64) DEFAULT NULL,
\`language\` char(2) DEFAULT NULL,
mailbox varchar(50) DEFAULT NULL,
pickupgroup varchar(10) DEFAULT NULL,
namedcallgroup varchar(64) DEFAULT NULL,
namedpickupgroup varchar(64) DEFAULT NULL,
qualify char(3) DEFAULT NULL,
regexten varchar(80) DEFAULT NULL,
rtptimeout char(3) DEFAULT NULL,
rtpholdtimeout char(3) DEFAULT NULL,
setvar varchar(100) DEFAULT NULL,
disallow varchar(100) DEFAULT 'all',
allow varchar(100) DEFAULT 'g729;ilbc;gsm;ulaw;alaw;g722;g723',
mohsuggest varchar(100) NOT NULL,
fullcontact varchar(80) NOT NULL DEFAULT '',
ipaddr varchar(15) NOT NULL DEFAULT '',
\`port\` mediumint(5) unsigned NOT NULL DEFAULT '0',
username varchar(80) NOT NULL DEFAULT '',
defaultuser varchar(80) NOT NULL DEFAULT '',
subscribecontext varchar(80) DEFAULT NULL,
directmedia enum('yes','no') DEFAULT NULL,
trustrpid enum('yes','no') DEFAULT NULL,
sendrpid enum('yes','no') DEFAULT NULL,
progressinband enum('never','yes','no') DEFAULT NULL,
promiscredir enum('yes','no') DEFAULT NULL,
useclientcode enum('yes','no') DEFAULT NULL,
callcounter enum('yes','no') DEFAULT NULL,
busylevel int(10) unsigned DEFAULT NULL,
allowoverlap enum('yes','no') DEFAULT 'yes',
allowsubscribe enum('yes','no') DEFAULT 'yes',
allowtransfer enum('yes','no') DEFAULT 'yes',
ignoresdpversion enum('yes','no') DEFAULT 'no',
template varchar(100) DEFAULT NULL,
videosupport enum('yes','no','always') DEFAULT 'no',
maxcallbitrate int(10) unsigned DEFAULT NULL,
rfc2833compensate enum('yes','no') DEFAULT 'yes',
\`session-timers\` enum('originate','accept','refuse') DEFAULT 'accept',
\`session-expires\` int(5) unsigned DEFAULT '1800',
\`session-minse\` int(5) unsigned DEFAULT '90',
\`session-refresher\` enum('uac','uas') DEFAULT 'uas',
t38pt_usertpsource enum('yes','no') DEFAULT NULL,
outboundproxy varchar(250) DEFAULT NULL,
callbackextension varchar(250) DEFAULT NULL,
registertrying enum('yes','no') DEFAULT 'yes',
timert1 int(5) unsigned DEFAULT '500',
timerb int(8) unsigned DEFAULT NULL,
qualifyfreq int(5) unsigned DEFAULT '120',
contactpermit varchar(250) DEFAULT NULL,
contactdeny varchar(250) DEFAULT NULL,
lastms int(11) NOT NULL,
regserver varchar(100) NOT NULL DEFAULT '',
regseconds int(11) NOT NULL DEFAULT '0',
useragent varchar(254) NOT NULL,
parkinglot varchar(128) DEFAULT NULL,
bar_mobile varchar(1) NOT NULL,
bar_fixed varchar(1) NOT NULL,
bar_int varchar(1) NOT NULL,
bar_13 varchar(1) NOT NULL
);"

mysql -u root -p"$mysql_root_pass" -e "ALTER TABLE telecube.sip_devices ADD PRIMARY KEY (id), ADD UNIQUE KEY \`name\` (\`name\`), ADD KEY \`host\` (\`host\`), ADD KEY \`useragent\` (\`useragent\`), ADD KEY \`call-limit\` (\`call-limit\`);"

mysql -u root -p"$mysql_root_pass" -e "CREATE TABLE IF NOT EXISTS telecube.voicemail_users (
uniqueid int(11) NOT NULL,
v2e_id int(10) unsigned NOT NULL,
\`context\` varchar(50) NOT NULL DEFAULT '',
mailbox varchar(11) NOT NULL DEFAULT '0',
\`password\` varchar(5) NOT NULL DEFAULT '0',
fullname varchar(150) NOT NULL DEFAULT '',
email text NOT NULL,
pager varchar(50) NOT NULL DEFAULT '',
tz varchar(10) NOT NULL DEFAULT 'central',
attach varchar(4) NOT NULL DEFAULT 'no',
maxmsg int(5) unsigned NOT NULL DEFAULT '999',
msg_format varchar(16) NOT NULL DEFAULT 'WAV',
saycid varchar(4) NOT NULL DEFAULT 'no',
dialout varchar(10) NOT NULL DEFAULT '',
callback varchar(10) NOT NULL DEFAULT '',
review varchar(4) NOT NULL DEFAULT 'no',
operator varchar(4) NOT NULL DEFAULT 'no',
envelope varchar(4) NOT NULL DEFAULT 'no',
sayduration varchar(4) NOT NULL DEFAULT 'no',
saydurationm tinyint(4) NOT NULL DEFAULT '1',
sendvoicemail varchar(4) NOT NULL DEFAULT 'no',
\`delete\` varchar(4) NOT NULL DEFAULT 'no',
nextaftercmd varchar(4) NOT NULL DEFAULT 'yes',
forcename varchar(4) NOT NULL DEFAULT 'no',
forcegreetings varchar(4) NOT NULL DEFAULT 'no',
hidefromdir varchar(4) NOT NULL DEFAULT 'yes',
stamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);"

mysql -u root -p"$mysql_root_pass" -e "ALTER TABLE telecube.voicemail_users ADD PRIMARY KEY (uniqueid), ADD KEY mailbox_context (mailbox,\`context\`), ADD KEY v2e_id (v2e_id);"

mysql -u root -p"$mysql_root_pass" -e "CREATE TABLE IF NOT EXISTS telecube.queues (
\`name\` varchar(128) NOT NULL,
qid int(10) unsigned NOT NULL,
musiconhold varchar(128) DEFAULT NULL,
announce varchar(128) DEFAULT NULL,
\`context\` varchar(128) DEFAULT NULL,
timeout int(11) DEFAULT NULL,
monitor_type varchar(50) NOT NULL,
monitor_format varchar(128) DEFAULT NULL,
queue_youarenext varchar(128) DEFAULT NULL,
queue_thereare varchar(128) DEFAULT NULL,
queue_callswaiting varchar(128) DEFAULT NULL,
queue_holdtime varchar(128) DEFAULT NULL,
queue_minutes varchar(128) DEFAULT NULL,
queue_seconds varchar(128) DEFAULT NULL,
queue_lessthan varchar(128) DEFAULT NULL,
queue_thankyou varchar(128) DEFAULT NULL,
queue_reporthold varchar(128) DEFAULT NULL,
announce_frequency int(11) DEFAULT NULL,
announce_round_seconds int(11) DEFAULT NULL,
announce_holdtime varchar(128) DEFAULT NULL,
retry int(11) DEFAULT NULL,
wrapuptime int(11) DEFAULT NULL,
maxlen int(11) DEFAULT NULL,
servicelevel int(11) DEFAULT NULL,
strategy varchar(128) DEFAULT NULL,
joinempty varchar(128) DEFAULT NULL,
leavewhenempty varchar(128) DEFAULT NULL,
eventmemberstatus varchar(4) DEFAULT NULL,
eventwhencalled varchar(4) DEFAULT NULL,
reportholdtime tinyint(1) DEFAULT NULL,
memberdelay int(11) DEFAULT NULL,
weight int(11) DEFAULT NULL,
timeoutrestart tinyint(1) DEFAULT NULL,
periodic_announce varchar(50) DEFAULT NULL,
periodic_announce_frequency int(11) DEFAULT NULL,
ringinuse tinyint(1) DEFAULT NULL,
setinterfacevar varchar(4) NOT NULL DEFAULT 'yes'
);"

mysql -u root -p"$mysql_root_pass" -e "ALTER TABLE telecube.queues ADD PRIMARY KEY (qid), ADD KEY \`name\` (\`name\`);"

mysql -u root -p"$mysql_root_pass" -e "CREATE TABLE IF NOT EXISTS telecube.queue_members (
uniqueid int(10) unsigned NOT NULL,
membername varchar(40) DEFAULT NULL,
queue_name varchar(128) DEFAULT NULL,
interface varchar(128) DEFAULT NULL,
penalty int(11) DEFAULT NULL,
paused tinyint(1) DEFAULT NULL
);"

mysql -u root -p"$mysql_root_pass" -e "ALTER TABLE telecube.queue_members ADD PRIMARY KEY (uniqueid), ADD UNIQUE KEY queue_interface (queue_name,interface), ADD KEY queue_name (queue_name);"

mysql -u root -p"$mysql_root_pass" -e "CREATE TABLE IF NOT EXISTS telecube.musiconhold (
\`name\` varchar(80) NOT NULL,
\`directory\` varchar(255) NOT NULL DEFAULT '',
application varchar(255) NOT NULL DEFAULT '',
\`mode\` varchar(80) NOT NULL DEFAULT '',
digit char(1) NOT NULL DEFAULT '',
sort varchar(16) NOT NULL DEFAULT '',
format varchar(16) NOT NULL DEFAULT ''
);"

mysql -u root -p"$mysql_root_pass" -e "ALTER TABLE telecube.musiconhold ADD PRIMARY KEY (\`name\`);"




# create certs folder
if [ ! -d /var/www/certs ]; then
	mkdir -p /var/www/certs
fi

# create self signed ssl certificate
if [ ! -f /var/www/certs/nginx.crt ]; then
	openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /var/www/certs/nginx.key -out /var/www/certs/nginx.crt -subj "/C=AU/ST=Victoria/L=Melbourne/O=Telecube Pty Ltd/OU=IT Department/CN=telecube.com.au"
fi

# Find the line, cgi.fix_pathinfo=1, and change the 1 to 0.
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini

# Start php5-fpm
service php5-fpm restart

# create a new config file
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default_BAK_$(date "+%Y-%m-%d-%H:%M:%S")

echo "# Default server configuration" > /etc/nginx/sites-available/default
echo "#" >> /etc/nginx/sites-available/default
echo "server {" >> /etc/nginx/sites-available/default
echo "        # configure ssl" >> /etc/nginx/sites-available/default
echo "        listen 443 ssl default_server;" >> /etc/nginx/sites-available/default
echo "        listen [::]:443 ssl default_server;" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # turn off gzip" >> /etc/nginx/sites-available/default
echo "        gzip off;" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # path to the certs" >> /etc/nginx/sites-available/default
echo "        ssl_certificate /var/www/certs/nginx.crt;" >> /etc/nginx/sites-available/default
echo "        ssl_certificate_key /var/www/certs/nginx.key;" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # doc root" >> /etc/nginx/sites-available/default
echo "        root /var/www/html;" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # add .php" >> /etc/nginx/sites-available/default
echo "        index index.php;" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # server name" >> /etc/nginx/sites-available/default
echo "        server_name _;" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # main rule" >> /etc/nginx/sites-available/default
echo "        location / {" >> /etc/nginx/sites-available/default
echo "                try_files \$uri \$uri/ =404;" >> /etc/nginx/sites-available/default
echo "        }" >> /etc/nginx/sites-available/default
echo "" >> /etc/nginx/sites-available/default
echo "        # main rule" >> /etc/nginx/sites-available/default
echo "        location ~ \.php$ {" >> /etc/nginx/sites-available/default
echo "                include snippets/fastcgi-php.conf;" >> /etc/nginx/sites-available/default
echo "                fastcgi_pass unix:/var/run/php5-fpm.sock;" >> /etc/nginx/sites-available/default
echo "        }" >> /etc/nginx/sites-available/default
echo "}" >> /etc/nginx/sites-available/default

service nginx restart

# check if the repo has been checked out and clone it if it hasn't
if [ -d /opt/telecube-pbx ]; then
	cd /opt/telecube-pbx
	git pull
else
	cd /opt
	git clone https://github.com/telecube/telecube-pbx.git
fi

rsync -av --delete /opt/telecube-pbx/html/ /var/www/html/

rsync -av --delete /opt/telecube-pbx/agi-bin /var/lib/asterisk/

echo "\n\n#########################################"
echo "Done!"
echo "You can log in to your server at the following address(es)"

HOST_IP=$(ifconfig | awk -F':' '/inet addr/&&!/127.0.0.1/{split($2,_," ");print _[1]}')
arr=$(echo $HOST_IP | tr " " "\n")
for x in $arr
do
    echo "https://$x/login.php"
done

echo "Default username/password is admin/admin"
echo "#########################################"

