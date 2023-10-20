#!/usr/local/bin/bash

# Because we take security seriously, we block outbound connections from the webserver. However this presents a problem for automatic certificate renewals.
# This script adjusts the firewall to allow the renewal to take place. Before doing so, services are disabled and re-enabled on completion.

gsed=/usr/local/bin/gsed
webserver="jexec webserver"
pf=/sbin/pfctl
pf_conf="/etc/pf.conf"

function blockOutbound {
	$gsed -i 's/#block out quick from $webserver to any/block out quick from $webserver to any/g' $pf_conf
	$pf -f $pf_conf
	pingTest
	if [[ $? == 0 ]]; then
		echo "Unable to confirm outbound connection is blocked"
		serviceNginx stop
		exit 1
	fi
	serviceSSH start
}

function pingTest {
	$webserver ping -c 1 1.1.1.1
}

function renewCerts {
	$webserver certbot --nginx renew
}

function serviceNginx {
	$webserver service nginx $1
}

function serviceSSH {
	$webserver service sshd $1
}

function unblockOutbound {
	serviceSSH stop
	$gsed -i 's/block out quick from $webserver to any/#block out quick from $webserver to any/g' $pf_conf
	$pf -f $pf_conf
	pingTest
	if [[ $? != 0 ]]; then
		echo "Unable to confirm outbound connection"
		blockOutbound
		exit 1
	fi
}

unblockOutbound
renewCerts
blockOutbound
