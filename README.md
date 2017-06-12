# Proxmox-prepare [![Build Status](https://travis-ci.org/Punk--Rock/Proxmox-prepare.svg?branch=master)](https://travis-ci.org/Punk--Rock/Proxmox-prepare)

## About

Preparing Proxmox VE after installation

## Screenshots

![screenshot](http://i.imgur.com/NzLskyS.png)

## Compatibility

Tested on 

* [x] Proxmox VE 4.4
* [x] Proxmox VE 5.0 beta 1
* [x] Proxmox VE 5.0 beta 2

## Features

- Disable "No valid subscription" pop-up message and remove Proxmox VE Enterprise repository from sources.list if you don't pay for Proxmox support subscription
- Install Fail2ban to protect Proxmox VE Web UI from too many connections attempts (default 4 max. retry and 12 hours of ban time you can modify it in ```/etc/fail2ban/jail.local```)
- Disable SSH root access
- Change SSH port number
- Generate a Let's Encrypt SSL certificate with auto renewals

## Installation

### Pre-requisites

Just a fresh install of Proxmox VE :)

### Recommendations

Run this script __just after__ installing Proxmox VE

```shell
wget https://raw.githubusercontent.com/Punk--Rock/Proxmox-prepare/master/proxmox_prepare.sh

chmod +x proxmox_prepare.sh

./proxmox_prepare.sh
```

## Troubleshooting

If you have problems with the Let's Encrypt SSL certificate you can uninstall it by executing ```fix_ssl.sh```

## More

If you use LXC containers (CT) and you want updated containers templates you can check [this repository](https://github.com/Punk--Rock/Proxmox-templates#proxmox-templates)

## Contact me

[![Twitter](https://cdn1.iconfinder.com/data/icons/logotypes/32/twitter-24.png)](https://twitter.com/Punk__R0ck) [@Punk__R0ck](https://twitter.com/Punk__R0ck)
