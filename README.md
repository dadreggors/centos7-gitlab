# The scripts
The scripts here are for 2 separate purposes. 
* A full blown installation on CentOS 7
* A docker container living on any platform

There are some pre-reqs that you should be aware of:
* You will need to have mysql or mariadb already installed and configured for network access
* You will need to run this as a user who has sudo access (preferably sudo NOPASSWD access)
* The script does expect firewalld and selinux to be running and enforcing

## CentOS7 Installer (GitLabInstaller.sh)
CentOS7 (and RHEL7) is based on Systemd now. This means there are issues with the rpm installer and the older scripts for the omnibus release. Just getting it installed was fine but then I realized that I preferred it to be on MariaDB (MySQL fork) because I have that already running and do not want another database server (Postgresql) running if I do not have too. This script kills 2 birds with one stone. It installs GitLab on CentOS 7 and it sets GitLab up to use MySQL/MariaDB. 

<b>Note:
This script is best run on a fresh install of CentOS 7 that has never had any extra software or users added.
Also, use this script at your own risk.</b>

## Docker scripts
For docker it is dead simple to bring up a preset container with GitLab. It is not so simple to add external storage for your repositories and use an external mysql database. This is why I chose to write this script, to have a real nice docker for GitLab with some built in data loss prevention. :-)


