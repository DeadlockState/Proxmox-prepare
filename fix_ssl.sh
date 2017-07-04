#!/bin/sh
rm -rf /.acme.sh/
		
rm -rf /root/.acme.sh

rm -rf /root/acme.sh-master/
		
rm -rf /root/.local/share/letsencrypt/

sed -i '/. "\/root\/.acme.sh\/acme.sh.env"/d' /root/.bashrc
		
rm -rf /etc/pve/.le/

rm -rf /etc/pve/local/pveproxy-ssl.*
		
pvecm updatecerts -f

service pveproxy restart

echo "OK now delete manually
47 0 * * * \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" > /dev/null
line in crontab with crontab -e"
