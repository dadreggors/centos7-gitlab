#!/bin/bash

##############################################################################
# Taken from 2 sources:
# https://github.com/sameersbn/docker-gitlab/
# http://docs.docker.com/installation/fedora/
##############################################################################

##########################
# Source in vars
##########################
. common.conf

if [ -z "${dbh_user}" ]; then
    echo "Could not source in common.conf, exiting..."
    exit 1
fi

##############################
# For docker (see fedora docker link above)
###############################
sudo yum -y install docker-io
sudo systemctl start docker
sudo systemctl enable docker
# ${USER} should contain your username not root!
usermod -a -G docker ${USER}

###############################
# For gitlab db
###############################
# Requires Mariadb on your host
# You should also preform the
# mysql_secure_installation
# before you start.

mysql -u root -p -Bse "
CREATE DATABASE IF NOT EXISTS `gitlabhq_production` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_unicode_ci`;
CREATE USER '${dbh_user}'@'%' IDENTIFIED BY PASSWORD('${dbh_pass}');
GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO '${dbh_user}'@'%';
CREATE USER '${dbh_user}'@'localhost' IDENTIFIED BY PASSWORD('${dbh_pass}');
GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON `gitlabhq_production`.* TO '${dbh_user}'@'localhost';
"
echo "Testing new mysql user '${dbh_user}'..."
mysql -u ${dbh_user} -p${dbh_pass} -Bse "select 'Successfully logged in\!';"

###############################
# Firewalld ports
###############################
# Open mysql port in forewall
sudo firewall-cmd --zone=public --add-service=mysql
sudo firewall-cmd --permanent --zone=public --add-service=mysql


###############################
# Mounted git repo folder
###############################
# Make the path to mount
mkdir -p ${gitlab_data_path}

# Set correct selinux context
sudo chcon -Rt svirt_sandbox_file_t ${gitlab_data_path}

# That is the end of the pre-docker setup
