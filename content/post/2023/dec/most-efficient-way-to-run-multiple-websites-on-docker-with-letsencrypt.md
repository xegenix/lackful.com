---
date: 2023-12-4
tags: ["blog","guides","general","docker","lets-encrypt","SSL","nginx","traefik","haproxy"]
title: 'Most efficient way to run multiple websites on Docker with LetsEncrypt SSL'
description: 'Need to reverse-proxy multiple Docker websites?'
featured: false
image: '/img/posts/rproxyflow.png'
---

# Most efficient way to run multiple sites on Docker w/ LetsEncrypt


## Article Summary

Let's face it, there are a million different ways to configure a server to run multiple web applications on Docker. Normally, I enjoy nothing more than seeing an entire stack provisioned by a compose file. Sadly, a single compose file isn't ideal for a development server with multiple domains and frequently changing applications. When you're application is production ready, I recommend switching to a Cloudflare Zero Trust tunnel to eliminate any unnecessary port exposure.

We are going to install certbot for provisioning SSL certificates to the domains we intend on using followed by installation of our desired reverse-proxy service. Your web applications will be SSL enabled from the moment they launch.


## Getting Started

Lets save ourselves a headache and set some temporary environment variables. They will be referencable until we end our existing terminal session. If you start a new session, remember you will need to rerun these commands. Modify the values below to suit your needs, replacing 'user@domain.tld' with a good email address and 'mydomain.tld' with your registered domain.

> export EMAIL="user@doman.tld"; export DOMAIN="example.com"


## Set temporary environment variables.

My end result would be (do not use - this unless you swapped with your information.

> export EMAIL="josh.*******@icloud.com"; export DOMAIN="nullidle.com"

Example reflecting information specific to my needs.

The first item to configure (yes, even before installing our proxy service) is the SSL certificate. Our DNS should already be configured to our domain's IPv4 address. If you just changed your A record for www and @ to your host's IPv4 address, check propagation across different regions using whatsmydns.net. It might take some locations longer than others to update. Otherwise to validate the domain is pointed correctly using the command line, use the ping command. See example below.

```
ping mydomain.tld -c1
ping www.mydomain.tld -c1
ping6 mydomain.tld -c1 # IPv6 configured hosts.
ping6 www.mydomain.tld -c1 # IPv6 configured hosts.
```

Everything is good? Perfect, onto configuring our SSL certificate.


## Install Certbot

We are going to use a snap package for our certbot install; these are a type of universally supported (cross-distribution) package for Linux based systems.

Depending on what distribution you are currently using, verify if snapd is installed using the following command. If snap is installed on the system, it will output the path of the snap binary.

```
josh@nullidle:~# command -v snap
/usr/bin/snap
```

If there is no output upon return, snap is not installed. You have a couple of options. Simply install snapd from your distribution's package manager, then you can install certbot from snap or any other packages which your distro's built-in package manager may lack. Otherwise feel free to install certbot directly from the operating systems package manager. Either way should produce a working certbot installation.

### Snap certbot installation:

> sudo snap install --classic certbot

### Verify Installation

The following command will verify if the snap bin directory is provided in $PATH. If it is not, a symlink will be created to /snap/bin/certbot under /usr/bin/certbot

> ! command -v certbot && sudo ln -sv /snap/bin/certbot /usr/bin/certbot

### Provision SSL Certificate

If you agree to the LetsEncrypt terms of service, run the below command to get your certificate created. You should not encounter any errors unless something is already utilizing port eighty.

> sudo certbot certonly --standalone --agree-tos -d $DOMAIN -m $EMAIL

NOTE: FOR ADDITIONAL DOMAINS ONLY
In order to successfully validate a second or third certificate, port 80 cannot be in use. Our reverse-proxy (nginx/HAProxy/Traefik) is already utilizing this port; we will need to temporarily stop the Nginx service. I have created a command chain to stop nginx, provision the certificate, start nginx, and show nginx status for your convenience.

The runtime of this chain should only take a second or two at most. If you jumped directly to this step, ensure you set the variables for DOMAIN & EMAIL if they are not already set. To check run the env command. (Setting variables example: DOMAIN=mydomain.tld; EMAIL=user@whatever.tld;)

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

> mv -v /etc/nginx/conf.d/default.conf /etc/nginx/.bkup-conf.d-default.conf*

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

> *:%s/YOUR_DOMAIN_NAME/example.com/g*

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
>systemctl status docker
> sudo systemctl enable docker # If status showed running OR
> sudo systemctl enable --now docker # If status showed stopped
> ```


or 


#### Other Init System
> 
> ```
> chkconfig docker on
> sudo service docker status
> sudo service docker start # run if service is not already xvstarted
> ```


### Docker Web Application Guides

Applications will be added as articles are created, there are no guides at the moment.
