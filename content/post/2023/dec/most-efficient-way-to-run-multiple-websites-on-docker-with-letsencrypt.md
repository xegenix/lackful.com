---
date: 2023-12-4
tags:
  [
    'blog',
    'guides',
    'general',
    'docker',
    'lets-encrypt',
    'SSL',
    'nginx',
    'traefik',
    'haproxy',
  ]
title: 'How to host multiple web applications with a reverse-proxy, Docker, and LetsEncrypt'
description: 'Need to reverse-proxy multiple Docker websites?'
featured: false
image: '/img/posts/rproxyflow.png'
---

## Article Summary

Let's face it, there are many different ways to run multiple web applications. Normally, I'd prefer a spinning up an entire stack provisioned by a compose file but it is not really ideal for an active development server running multiple domains and frequently changing applications. Once you have moved past the phase of development, consider using a Cloudflare tunnel to eliminate any unnecessary port exposure.

First we will start by provisioning the SSL certificates, followed by installing our reverse-proxy service. Once the process is complete, you should (ideally) have a web application that can be securely delivered to an interested end-user.

## Getting Started

We are going to do a little preperation by settings some environment variables. It is worth noting, if you close the terminal or use a different terminal window they will not be referencable. Either set them each time you launch a terminal during this process or add them into your profile using ~/.bash_profile or ~/.zshrc depending on which shell instance you use. Modify the values below to suit your needs, replacing 'user@domain.tld' with a good email address and 'mydomain.tld' with the domain you intend on using with the application.

> export EMAIL="user@doman.tld"> export DOMAIN="example.com"

For purpose of demonstration, I'm using the following.

> export EMAIL="noreply@nullidle.com"
> export DOMAIN="nullidle.com"

Once those have been set, we'll start by provisioning our SSL certificate. This guide assumes your DNS is already configured on the domain you intend on using. If this has not been done, there is no point to proceeding past this step. Updating your DNS records may required a little time for the new entries to propogate depending upon the TTL value. You can check your domain using the website whatssmydns.net, it'll check the DNS records you query from a nunber of different locations. If it has propogated to your region, it should reflect the new value. Some locations can take longer than others. Otherwise, if you would rather not leave the comfort of your terminal, just ping it.

```
ping mydomain.tld -c1
ping www.mydomain.tld -c1
ping6 mydomain.tld -c1 # IPv6 configured hosts.
ping6 www.mydomain.tld -c1 # IPv6 configured hosts.
```

Everything good? Certbot installation time, to the terminal!

## Install Certbot

Use one of the following options to install certbot into the system.

### Install Using Snap Package

Snap packages are ususally cross-distro supported packages for Linux based systems. If you are using Ubuntu Server, the packaging system is available right out of the box. Otherwise you may need to install snapd from your distro's package management system.

The below command will check if the snap binary exists on your device. If installed, it will output the location of the binary. If not, expect no output to occur.

```
command -v snap
/usr/bin/snap
```

Not found? Try installing from your distro's package manager.

For those of you who have snap, run the following command to install certbot.

```
sudo snap install --classic certbot
```

### Verify Installation

Lets take a second to verify the installation. The following command will check if certbot exists within the binary path, and if not - symlink certbot to the /usr/bin/certbot.

```
! command -v certbot && sudo ln -sv /snap/bin/certbot /usr/bin/certbot
```

### Provision SSL Certificate

Time to generate the SSL. Assuming you agree to the LetsEncrypt TOS, run the below command to create your certificate. No errors should occur (hopefully) unless port 80 is alrady in use.

```
sudo certbot certonly --standalone --agree-tos -d $DOMAIN -m $EMAIL
```

** Note on adding additional domains: **

In order to successfully validate a second or third certificate, we need port 80 to be unutilized. Our reverse-proxy (nginx/HAProxy/Traefik) is already running on this port; therefore we need to temporarily stop the proxy service. The below command chain will stop nginx, provision the certificate, start nginx, and show it's status. If you chose not to use nginx, replace the service name with what you did choose.

If you jumped directly to this section, set environment variables DOMAIN, and EMAIL. You can validate by running the env command. (Setting variables example: DOMAIN=mydomain.tld; EMAIL=user@whatever.tld;) The entire time to run the below command should only be a few seconds at most.

> $( sudo systemctl stop nginx && sudo certbot certonly --standalone --agree-tos -d $DOMAIN -m $EMAIL ); systemctl start nginx; systemctl status nginx;

## Setup Reverse Proxy

### Install Nginx

We will be using nginx as a reverse proxy to our upstream applications. Run the command specific to your Linux distribution.

Debian / Ubuntu-Based Distributions

> apt install nginx

RHEL-Based Distributions (RedHat/Fedora/CentOS/Scientific/Oracle/Alma/Rocky)

> dnf install nginx

Arch-Based Distributions

> pacman -S nginx

Gentoo

> emerge nginx

Alpine

> apk add nginx

### Disable Default Configuration

We won't be using the default configuration included with the nginx installation; therefore, we are simply going to remove the symlink from /etc/nginx/sites-enabled/default that points to /etc/nginx/sites-available/default

> sudo unlink /etc/nginx/conf.d/sites-enabled/default

For some Linux distributions, the default configuration file might be located in /etc/nginx/conf.d/default.conf - just move this file elsewhere outside of the conf.d folder.

> mv -v /etc/nginx/conf.d/default.conf /etc/nginx/.bkup-conf.d-default.conf\*

### Pre-Configure Upstream Application

If your default.conf was found in /etc/nginx/conf.d, follow the below instructions but use the /etc/nginx/conf.d path instead and skip step 3.

    Open your favorite editor of choice to the following path

- /etc/nginx/sites-available/YOUR_DOMAIN_NAME.conf

Paste the below configuration into the file and replace the six instances of YOUR_DOMAIN_NAME and the instance of EXPOSED_CONTAINER_PORT with the appropriate values. The EXPOSED_CONTAINER_PORT occurrence should be set to the Docker web application's exposed port (example: 3000, 8080, or 9000).

```
server {
  listen 80;
  listen [::]:80;
  server_name YOUR_DOMAIN_NAME;
  location /.well-known/acme-challenge/ { root /usr/share/nginx/html; allow all; }
  location / { return 301 https://$server_name$request_uri; }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name YOUR_DOMAIN_NAME;

  access_log /var/log/nginx/YOUR_DOMAIN_NAME.access.log;
  error_log /var/log/nginx/YOUR_DOMAIN_NAME.error.log;
  client_max_body_size 20m;

  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
  ssl_prefer_server_ciphers on;
  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:10m;

  ssl_certificate     /etc/letsencrypt/live/YOUR_DOMAIN_NAME/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/YOUR_DOMAIN_NAME/privkey.pem;

  location / {
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Proto https;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass http://localhost:EXPOSED_CONTAINER_PORT;
  }
}
```

Vim & NeoVim users: Save time by updating all instances within our config file. Type the following in command mode.

> _:%s/YOUR_DOMAIN_NAME/example.com/g_

Now it's time to rescue those of you not familiar with Vim but tried the easy way of editing everything at once. We need to save the changes and exit.

> :x!

More problems? Perhaps you forget to run sudo when editing the file? Trust me, I dislike that "oh shit, I did all this for nothing." feeling too.
If your user has sudo rights without password, give this a shot from within vim.

> :w! sudo tee %

Ok, now we have a saved configuration file (hopefully). Lets setup the symlink to enable the site in nginx.

> sudo ln -sv /etc/nginx/sites-available/YOUR_DOMAIN_NAME.conf /etc/nginx/sites-enabled/YOUR_DOMAIN_NAME.conf`

These changes will not go into effect until we restart the proxy service.

```
systemctl restart nginx # systemd
# OR
service nginx restart # other init.
```

## Docker

I will add links to this section for the setup of individual web applications. If you do not already have Docker installed and wish to go this route, follow the below installation steps.

### Easy Install

```
curl -fsSL https://get.docker.com/ | sh
```

Once it has installed we are going to create and add your current user (this should not be root) to the Docker group. After user has been added to the docker group, changes will not take effect until logout has occurred. Continue command execution under sudo capable user other than root.

```
sudo groupadd docker && sudo usermod -aG docker $USER
```

It is time to see if Docker is currently running, on a systemd based system run the below command to verify status.

### Verify Install

We need Docker to start at boot incase the system is rebooted at some point in time, depending on your distributions provided init system, use one or the other set of commands to enable Docker at boot and to start the service.

#### Systemd Init System

> ```
> systemctl status docker
> sudo systemctl enable docker # If status showed running OR
> sudo systemctl enable --now docker # If status showed stopped
> ```

or

#### Other Init System

> ```
> chkconfig docker on
> sudo service docker status
> sudo service docker start # run if service is not already xvstarted
> ```

### Docker Web Application Guides

Applications will be added as articles are created, there are no guides at the moment.
