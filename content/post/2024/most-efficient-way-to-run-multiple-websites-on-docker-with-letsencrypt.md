# Most efficient way to run multiple sites on Docker w/ LetsEncrypted 

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
