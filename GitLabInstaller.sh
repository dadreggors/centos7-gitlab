#!/bin/bash

##############################################################################################
# Much of this is taken directly from these install documents:
#
# https://gitlab.com/gitlab-org/gitlab-ce/blob/7-1-stable/doc/install/installation.md
# https://gitlab.com/gitlab-org/gitlab-ce/blob/7-1-stable/doc/install/database_mysql.md
#
# This is specifically written to work on CentOS 7.x
# There are some assumptions made here:
#   1. You are logged in as a user that has sudo "NOPASSWD: ALL" access
#   2. You have full internet and yum repo access
##############################################################################################

##########################
# Needed VARS
# Change these as needed
##########################
me=$(hostname)
ip=$(ip a|awk '/inet /&& !/lo$/{split($2, ip, "/"); print ip[1]}')
email_from="git@${me}"
db_pass="gitlabuser"
githome="/home/git"

##########################
# Dependencies
##########################
sudo rpm -i http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
sudo yum -y install patch gcc gcc-c++ mariadb-server \
  mariadb-libs mariadb mariadb-devel libicu-devel \
  rubygem-rake mlocate git ruby rubygem-bundler \
  redis nginx ruby-devel vim policycoreutils-devel

# Need for mdns, or else internal links fail
sudo sh -c 'echo "${ip}    ${me}" >> /etc/hosts'

# Enable and start redis
sudo /bin/systemctl enable redis
sudo /bin/systemctl start redis



##########################
# Git User
##########################
sudo useradd -c "Git" git

##########################
# Database setup
##########################

# Enable the server to start on boot
sudo /bin/systemctl enable mariadb

# Start the server
sudo /bin/systemctl start mariadb

# Secure the server
mysql_secure_installation

# Ensure you have MySQL version 5.5.14 or later
mysql --version

# Login to MySQL
# Type the database root password

echo "The Mysql root user password is needed here."
mysql -u root -p -Bse "
CREATE USER 'git'@'localhost' IDENTIFIED BY '${db_pass}';
SET storage_engine=INNODB;
CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET 'utf8' COLLATE 'utf8_unicode_ci';
GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'git'@'localhost';
"

# Try connecting to the new database with the new user
sudo -u git -H mysql -u git -p${db_pass} -D gitlabhq_production -Bse "select 'The initial database setup is now complete\!\!';"


##########################
# GitLab
##########################
sudo chmod 755 ${githome}
cd ${githome}

## Clone GitLab repository
sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-1-stable gitlab

## Go to gitlab dir
cd ${githome}/gitlab

## Configure it

# Copy the example GitLab config
sudo -u git -H cp -v config/gitlab.yml.example config/gitlab.yml

# Make sure to change "localhost" to the fully-qualified domain name of your
# host serving GitLab where necessary
# Also set the git path and change your email
sudo -u git -H sed -i "s|host: localhost|host: ${me}|" config/gitlab.yml
sudo -u git -H sed -i "s|email_from:.*|email_from: ${email_from}|" config/gitlab.yml
sudo -u git -H sed -i "s|bin_path:.*|bin_path: $(which git)|" config/gitlab.yml

# Make sure GitLab can write to the log/ and tmp/ directories
sudo chown -R git log/
sudo chown -R git tmp/
sudo chmod -R u+rwX log/
sudo chmod -R u+rwX tmp/

# Create directory for satellites
sudo -u git -H mkdir /home/git/gitlab-satellites
sudo chmod u+rwx,g=rx,o-rwx /home/git/gitlab-satellites

# Make sure GitLab can write to the tmp/pids/ and tmp/sockets/ directories
sudo chmod -R u+rwX tmp/pids/
sudo chmod -R u+rwX tmp/sockets/

# Make sure GitLab can write to the public/uploads/ directory
sudo chmod -R u+rwX  public/uploads

# Copy the example Unicorn config
sudo -u git -H cp -v config/unicorn.rb.example config/unicorn.rb

# Enable cluster mode if you expect to have a high load instance
# Ex. change amount of workers to 3 for 2GB RAM server
#sudo -u git -H editor config/unicorn.rb

# Copy the example Rack attack config
sudo -u git -H cp -v config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

# Configure Git global settings for git user, useful when editing via web
# Edit user.email according to what is set in gitlab.yml
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "${email_from}"
sudo -u git -H git config --global core.autocrlf input


## Configure GitLab DB Settings
# PostgreSQL only:
#sudo -u git cp config/database.yml.postgresql config/database.yml

# MySQL only:
sudo -u git cp config/database.yml.mysql config/database.yml

# MySQL and remote PostgreSQL only:
# Update username/password in config/database.yml.
# If you followed the database guide then please do as follows:
# Change 'secure password' with the value you have given to $password
# You can keep the double quotes around the password
sudo -u git -H sed -i "s|username.*|username: git|;s|password.*|password: \"${db_pass}\"|" config/database.yml

# PostgreSQL and MySQL:
# Make config/database.yml readable to git only
sudo -u git -H chmod o-rwx config/database.yml


## Install Gems
cd ${githome}/gitlab

# For PostgreSQL (note, the option says "without ... mysql")
#sudo -u git -H bundle install --deployment --without development test mysql aws

# Or if you use MySQL (note, the option says "without ... postgres")
sudo -u git -H bundle install --deployment --without development test postgres aws


## Install GitLab Shell
# Go to the GitLab installation folder:
cd ${githome}/gitlab

# Run the installation task for gitlab-shell (replace `REDIS_URL` if needed):
sudo -u git -H bundle exec rake gitlab:shell:install[v1.9.6] REDIS_URL=redis://localhost:6379 RAILS_ENV=production

# By default, the gitlab-shell config is generated from your main gitlab config.
#
# Note: When using GitLab with HTTPS please change the following:
# - Provide paths to the certificates under `ca_file` and `ca_path` options.
# - The `gitlab_url` option must point to the https endpoint of GitLab.
# - In case you are using self signed certificate set `self_signed_cert` to `true`.
# See #using-https for all necessary details.
#
# You can review (and modify) the gitlab-shell config as follows:
# sudo -u git -H vim /home/git/gitlab-shell/config.yml


## Initialize the database and activate advanced features
sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

# Type 'yes' to create the database tables.

# When done you see 'Administrator account created:
#login.........root
#password......5iveL!fe






## Install Init Script

# Download the init script (will be /etc/init.d/gitlab):

sudo cp -v lib/support/init.d/gitlab /etc/init.d/gitlab
# And if you are installing with a non-default folder or user copy and edit the defaults file:

# sudo cp lib/support/init.d/gitlab.default.example /etc/default/gitlab
# If you installed GitLab in another directory or as a user other than the default you should change these settings in /etc/default/gitlab. Do not edit `/etc/init.d/gitlab as it will be changed on upgrade.

# Make GitLab start on boot:
sudo chkconfig gitlab on
#sudo update-rc.d gitlab defaults 21
#Set up logrotate

sudo cp -v lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

#Check Application Status
#Check if GitLab and its environment are configured correctly:

sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production


## Compile assets
sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production


## Start Your GitLab Instance
sudo /sbin/service gitlab start
# or
# sudo /etc/init.d/gitlab restart


##########################
# Nginx
##########################

## Note: Nginx is the officially supported web server for GitLab. 
# If you cannot or do not want to use Nginx as your web server, have a look at the GitLab recipes.


## Site Configuration

## Copy the example site config:

sudo cp -v lib/support/nginx/gitlab /etc/nginx/conf.d/gitlab


## Make sure to edit the config file to match your setup:

# Change YOUR_SERVER_FQDN to the fully-qualified
# domain name of your host serving GitLab.
sudo sed -i "s/YOUR_SERVER_FQDN/$(hostname)/" /etc/nginx/conf.d/gitlab

## Note: If you want to use https, replace the gitlab nginx config with gitlab-ssl. See Using HTTPS for all necessary details.

# SELinux needs to allow nginx
sudo grep nginx /var/log/audit/audit.log | sudo /bin/audit2allow -m nginx > nginx.te
sudo grep nginx /var/log/audit/audit.log | sudo /bin/audit2allow -M nginx
sudo /usr/sbin/semodule -i nginx.pp

# Now open port 80 in the firewall
sudo /usr/bin/firewall-cmd --zone=public --add-service=http # Opens port now
sudo /usr/bin/firewall-cmd --permanent --zone=public --add-service=http # Makes change persistent
sudo /usr/bin/firewall-cmd --zone=public --list-services # Shows you what service ports are open 

## Restart nginx
sudo /bin/systemctl restart nginx


echo
echo
echo
echo "You can now browse to \"http://${me}/\" and log in for the first time."
echo
echo "The initial user/pass is root/5iveL!fe"
echo "You will be prompted to change that after logging in."

## Done!

# Double-check Application Status
# 
# To make sure you didn't miss anything run a more thorough check with:
# 
# # sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production
# 
# If all items are green, then congratulations on successfully installing GitLab!
# 
# NOTE: Supply SANITIZE=true environment variable to gitlab:check to omit project names from the output of the check command.
# 
# Initial Login
# 
# Visit YOUR_SERVER in your web browser for your first GitLab login. The setup has created an admin account for you. You can use it to log in:
# 
# root
# 5iveL!fe
# 
# Important Note: Please go over to your profile page and immediately change the password, so nobody can access your GitLab by using this login information later on.
# 
# Enjoy!
# 
# Advanced Setup Tips
# 
# Using HTTPS
# 
# To recapitulate what is needed to use GitLab with HTTPS:
# 
# In gitlab.yml set the https option to true
# In the config.yml of gitlab-shell set the relevant options (see the install GitLab Shell section of this document).
# Use the gitlab-ssl nginx example config instead of the gitlab config.
# Additional markup styles
# 
# Apart from the always supported markdown style there are other rich text files that GitLab can display. But you might have to install a dependency to do so. Please see the github-markup gem readme for more information.
# 
# Custom Redis Connection
# 
# If you'd like Resque to connect to a Redis server on a non-standard port or on a different host, you can configure its connection string via the config/resque.yml file.
# 
# example
# production: redis://redis.example.tld:6379
# If you want to connect the Redis server via socket, then use the "unix:" URL scheme and the path to the Redis socket file in the config/resque.yml file.
# 
# example
# production: unix:/path/to/redis/socket
# Custom SSH Connection
# 
# If you are running SSH on a non-standard port, you must change the GitLab user's SSH config.
# 
# Add to /home/git/.ssh/config
# host localhost          # Give your setup a name (here: override localhost)
#     user git            # Your remote git user
#     port 2222           # Your port number
#     hostname 127.0.0.1; # Your server name or IP
# You also need to change the corresponding options (e.g. ssh_user, ssh_host, admin_uri) in the config\gitlab.yml file.# 
# 
# LDAP authentication
# 
# You can configure LDAP authentication in config/gitlab.yml. Please restart GitLab after editing this file.
# 
# Using Custom Omniauth Providers
# 
# GitLab uses Omniauth for authentication and already ships with a few providers preinstalled (e.g. LDAP, GitHub, Twitter). But sometimes that is not enough and you need to integrate with other authentication solutions. For these cases you can use the Omniauth provider.
# 
# Steps
# 
# These steps are fairly general and you will need to figure out the exact details from the Omniauth provider's documentation.
# 
# Stop GitLab:
# 
# sudo service gitlab stop
# Add the gem to your Gemfile:
# 
# gem "omniauth-your-auth-provider"
# If you're using MySQL, install the new Omniauth provider gem by running the following command:
# 
# sudo -u git -H bundle install --without development test postgres --path vendor/bundle --no-deployment
# If you're using PostgreSQL, install the new Omniauth provider gem by running the following command:
# 
# sudo -u git -H bundle install --without development test mysql --path vendor/bundle --no-deployment
# These are the same commands you used in the Install Gems section with --path vendor/bundle --no-deployment instead of --deployment.
# Start GitLab:
# 
# `sudo service gitlab start`
