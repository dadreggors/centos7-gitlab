#!/bin/bash

###################################################################
# Flags & Vars
#
# The GITLAB_XX_PORT vars are the forwarded ports for
# connecting to gitlab. Think DNAT in firewall. :-)
# The work with the -p flag which creates the forward
# and this variable is used inside the container to
# be aware of the forwarded port.
#
# The DB_XX vars should be changed to match your DB
# settings (ip, database, user, pass, etc...)
#
# The SMTP_XX vars are for your external smtp server.
# This is needed so you can email
#
# The '-e' flag sets environment vars inside the container
# The '-p' flag creates a forwarded port [external:internal]
# The '-h' sets the containers internal hostname
# The "-it" is 2 flags (-i and -t)
#   '-i' sets interactive mode so you can answer prompts
#   '-t' attaches a tty to the container for interactive mode
# The '-v' bind mounts a volume (directory) to the container
#   at the specified path [local path:container path]
# The '-d' detaches teh container from the terminal (daemon mode)  
###################################################################

##########################
# Source in vars
##########################
. common.conf

if [ -z "${dbh_user}" ]; then
    echo "Could not source in common.conf, exiting..."
    exit 1
fi

#########################
# Functions
##########################
function first_run {
    # First run only
    docker run --name="${container}" -it --rm -h ${int_hostname} \
    -p ${ssh_fwd_prt}:22 -p ${web_fwd_port}:80 \
    -e "GITLAB_PORT=${web_fwd_port}" -e "GITLAB_SSH_PORT=${ssh_fwd_port}" \
    -e "DB_HOST=${dbh_ip}" -e "DB_NAME=gitlabhq_production" \
	-e "DB_USER=${dbh_user}" -e "DB_PASS=${dbh_pass}" \
    -e "GITLAB_HOST=${int_hostname}" -e "GITLAB_EMAIL=${gl_email_from}" \
    -e "SMTP_USER=${email_relay_user}" -e "SMTP_PASS=${email_relay_pass}" \
    -v ${gitlab_data_path}:/home/git/data \
    sameersbn/gitlab:7.1.1 app:rake gitlab:setup force=yes
}

function run {
    # All subsequent runs
    docker run --name="${container}" -d -h ${int_hostname} \
    -p ${ssh_fwd_prt}:22 -p ${web_fwd_port}:80 \
    -e "GITLAB_PORT=${web_fwd_port}" -e "GITLAB_SSH_PORT=${ssh_fwd_port}" \
    -e "DB_HOST=${dbh_ip}" -e "DB_NAME=gitlabhq_production" \
	-e "DB_USER=${dbh_user}" -e "DB_PASS=${dbh_pass}" \
    -e "GITLAB_HOST=${int_hostname}" -e "GITLAB_EMAIL=${gl_email_from}" \
    -e "SMTP_USER=${email_relay_user}" -e "SMTP_PASS=${email_relay_pass}" \
    -v ${gitlab_data_path}:/home/git/data \
    sameersbn/gitlab:7.1.1
}

case ${1} in
	"first")
		first_run
		;;
	"run")
		run
		;;
	*)
		echo "Incorrect argument, please specify 'first' or 'run' as the first argument."
		;;
esac
