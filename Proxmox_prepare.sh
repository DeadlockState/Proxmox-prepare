#!/bin/sh
if [ $USER != "root" ] ; then
	echo ""
	echo " This script must be run as root !"
	echo ""
	
	exit 1
fi

if ! ping -c 1 google.com >> /dev/null 2>&1 ; then
	echo ""
	echo " You are not connected to internet please check your connection !"
	echo ""
	
	exit 2
fi

green="\033[1;32m"
blue="\033[1;34m"
orange="\033[0;33m"
red="\033[1;31m"
nc="\033[0m"

version=`pveversion | awk -v FS="(manager/| \()" '{print $2}'`
email=`head -n 1 /etc/pve/user.cfg | grep -o -P '(?<=:::).*(?=::)'`
fqdn=`hostname -f`

echo ""
echo " Proxmox VE "$version
echo ""

read -p " What's your email address ? (will be used if you generate a SSL certificate) ["$email"] " new_email
echo ""

if [ -z "$new_email" ]; then
		new_email=$email
	fi

read -p " What's the FQDN of this Proxmox server ? (will be used if you generate a SSL certificate) ["$fqdn"] " new_fqdn
echo ""

if [ -z "$new_fqdn" ]; then
	new_fqdn=$fqdn
fi
	
sed -i 's/search /#search#/g' /etc/resolv.conf

echo " "${blue}"Note : if you don't have any paid support subscription this script will disable \"No valid subscription\" pop-up message and will remove Proxmox VE Enterprise repository from sources.list"${nc}
read -p " Are you using a paid support subscription on your Proxmox server ? [y/N] " subscription
echo ""

if [ "$subscription" != "y" ] ; then
	if [ -f "/usr/share/pve-manager/ext6/pvemanagerlib.js" ] ; then
		sed -i 's/if (data.status !== '\''Active'\'') {/if (data.status == '\''Active'\'') {/g' /usr/share/pve-manager/ext6/pvemanagerlib.js
	fi
	
	if [ -f "/usr/share/pve-manager/js/pvemanagerlib.js" ] ; then
		sed -i 's/if (data.status !== '\''Active'\'') {/if (data.status == '\''Active'\'') {/g' /usr/share/pve-manager/js/pvemanagerlib.js
	fi
			
	sed -i 's/deb https/#deb #https/g' /etc/apt/sources.list.d/pve-enterprise.list

	apt-get update > /dev/null 2>&1
fi
		
read -p " Do you want install Fail2ban and enable it for Proxmox (http, https and 8006 ports) ? [Y/n] " install_fail2ban
echo ""
		
if [ "$install_fail2ban" != "n" ] ; then
	apt-get install -y fail2ban > /dev/null 2>&1
			
	cd /etc/fail2ban/
			
	touch jail.local
			
	echo "[proxmox]
enabled = true
port = http,https,8006
filter = proxmox
logpath = /var/log/daemon.log
maxretry = 4
bantime = 43200" > jail.local

	cd filter.d/
		
	touch proxmox.conf
		
	echo "[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =" > proxmox.conf

	service fail2ban restart
fi
		
if grep -qF "PermitRootLogin yes" /etc/ssh/sshd_config; then
	read -p " SSH access by root is authorized, do you want disable it ? [y/N] " ssh_root_access
	echo ""
			
	if [ "$ssh_root_access" = "y" ] ; then
		sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
				
		service ssh restart && service sshd restart
	fi
else
	ssh_root_access="N"
fi
		
if grep -qF "Port 22" /etc/ssh/sshd_config; then
	read -p " SSH port is default 22 do you want change it ? [y/N] " ssh_port
	echo ""
			
	if [ "$ssh_port" = "y" ] ; then
		read -p " Please enter new port number for SSH : " ssh_port_number
		echo ""
				
		if grep -qF "#Port 22" /etc/ssh/sshd_config; then
			sed -i 's/# Port 22/Port '$ssh_port_number'/g' /etc/ssh/sshd_config
		else
			sed -i 's/Port 22/Port '$ssh_port_number'/g' /etc/ssh/sshd_config
		fi
				
		service ssh restart && service sshd restart
	fi
fi
		
read -p " Do you want generate a Let's Encrypt SSL certificate for your Proxmox server ? [Y/n] " ssl_certificate
echo ""

if [ "$ssl_certificate" != "n" ] ; then
	# Open port 80 for Let's Encrypt SSL certificate validation
	iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
	iptables -A OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT
			
	apt-get install -y git-core > /dev/null 2>&1
			
	cd /root/
			
	git clone https://github.com/Neilpang/acme.sh.git acme.sh-master --quiet
			
	mkdir /etc/pve/.le
			
	cd acme.sh-master/
			
	./acme.sh --install --accountconf /etc/pve/.le/account.conf --accountkey /etc/pve/.le/account.key --accountemail "$new_email" > /dev/null 2>&1
		
	./acme.sh --issue --standalone --keypath /etc/pve/local/pveproxy-ssl.key --fullchainpath /etc/pve/local/pveproxy-ssl.pem --reloadcmd "systemctl restart pveproxy" -d $new_fqdn
			
	# Close port 80 previously opened
	iptables -D INPUT -p tcp -m tcp --dport 80 -j ACCEPT
	iptables -D OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT
	echo ""
fi

if [ "$ssl_certificate" != "n" ] ; then
	echo " "${green}"https"${nc}"://"$new_fqdn":8006"
else
	echo " "${red}"https"${nc}"://"$new_fqdn":8006"
fi
		
if [ "$ssh_root_access" != "y" ] ; then
	if [ "$ssh_port" = "y" ] ; then
		echo " ssh -p "$ssh_port_number" root@"$new_fqdn
	else
		echo " ssh root@"$new_fqdn
	fi
fi

echo ""
echo " For all your changes to be applied you must be restart the server"
read -p " Do you want restart now ? [Y/n] " restart

if [ "$restart" != "n" ] ; then
	reboot
fi
