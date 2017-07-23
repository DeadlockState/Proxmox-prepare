#!/bin/sh
if [ $USER != "root" ] ; then
	echo ""
	echo " This script must be run as root !"
	echo ""
	
	exit
fi

if ! ping -c 1 google.com >> /dev/null 2>&1 ; then
	echo ""
	echo " You are not connected to internet please check your connection !"
	echo ""
	
	exit
fi

green="\033[1;32m"
blue="\033[1;34m"
orange="\033[0;33m"
red="\033[1;31m"
nc="\033[0m"

# Post treatment if you are using Proxmox on an Online.net Dedibox
if grep -qF "online.net" /etc/apt/sources.list; then
	echo ""
	echo " Proxmox is installed on an Online.net Dedibox please wait a few seconds while the script is preparing your server..."
	
	cd /etc/apt/

	mv sources.list sources.list.default

	touch sources.list
	
	if grep -qF "stretch" /etc/apt/sources.list; then
		echo "deb http://ftp.debian.org/debian stretch main contrib

# security updates
deb http://security.debian.org stretch/updates main contrib" > sources.list
	else
		echo "deb http://ftp.debian.org/debian jessie main contrib

# security updates
deb http://security.debian.org jessie/updates main contrib" > sources.list
	fi
	
	cd sources.list.d/
	
	rm pve-install-repo.list
	
	apt-get update > /dev/null 2>&1
	
	cd /etc/pve/
	
	touch user.cfg
	
	echo "root:root@pam:1:0:::::" > user.cfg
	
	sed -i '/nameserver 127.0.0.1/d' /etc/resolv.conf
fi
# Post treatment if you are using Proxmox on an Online.net Dedibox

version=`pveversion | awk -v FS="(manager/| )" '{print $2}'`
email=`head -n 1 /etc/pve/user.cfg | grep -o -P '(?<=:::).*(?=::)'`
fqdn=`hostname -f`

echo ""
echo " Running Proxmox VE "$version
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
	ssh_root_access="n"
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

read -p " Do you want add a new bridged network ? [Y/n] " add_bridged_network
echo ""

if [ "$add_bridged_network" != "n" ] ; then
	if grep -qF "vmbr1" /etc/network/interfaces; then
		echo " "${red}"vmbr1 already exists"${nc}
		echo ""
	else
		rand_ip_network=$(shuf -i 100-200 -n 1)
		
		cd /root/

		touch networking-up.sh networking-down.sh

		echo "# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Allow traffic on vmbr1 from vmbr0
iptables -t nat -A POSTROUTING -s '192.168."$rand_ip_network".0/24' -o vmbr0 -j MASQUERADE" >> networking-up.sh

		echo "# Disable IP forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward

# Close traffic on vmbr1 from vmbr0
iptables -t nat -D POSTROUTING -s '192.168."$rand_ip_network".0/24' -o vmbr0 -j MASQUERADE" >> networking-down.sh
		
		chmod +x networking-*.sh
		
		echo "
auto vmbr1
iface vmbr1 inet static
	address  192.168."$rand_ip_network".254
	netmask  255.255.255.0
	bridge_ports none
	bridge_stp off
	bridge_fd 0
	post-up /root/networking-up.sh
	post-down /root/networking-down.sh" >> /etc/network/interfaces
	
		service networking restart
		
		echo " "${green}"vmbr1 (192.168."$rand_ip_network".0/24) was added"${nc}
		echo ""
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
	
	if [ "$?" = 0 -o "$?" = 2 ] ; then
		acme_sh="ok"
	else
		acme_sh="nok"
	fi
	
	# Close port 80 previously opened
	iptables -D INPUT -p tcp -m tcp --dport 80 -j ACCEPT
	iptables -D OUTPUT -p tcp -m tcp --dport 80 -j ACCEPT
	echo ""
fi

if [ "$ssl_certificate" != "n" ] ; then
	if [ "$acme_sh" = "ok" ] ; then
		echo " "${green}"https"${nc}"://"$new_fqdn":8006"
	else
		echo " "${red}"https"${nc}"://"$new_fqdn":8006"
	fi
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
echo ""

if [ "$restart" != "n" ] ; then
	reboot
fi
