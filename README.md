## Setup based on Raspbian image

- Download [Raspbian Jessie Lite](https://www.raspberrypi.org/downloads/).
- Follow the [installation instruction](https://www.raspberrypi.org/documentation/installation/installing-images/README.md) to create the SD card.
- Start your RPi connected to Ethernet.
- Plug the iC880a (**WARNING**: first power plug to the wall socket, then to
the gateway DC jack,and ONLY THEN USB to RPi!).
- Connect monitor and keyboard to the RPi.
- Default password of a plain-vanilla RASPBIAN install for user `pi` is `raspberry`.

- You may want to enabled `ssh` server on the RPi (as it has been disabled by default)
and expand the filesystem . Use `raspi-config` utility (3 Interfacing options. P2 SSH.
Then go to 1 Expand filesystem):

        $ sudo raspi-config

- Reboot
- Configure locales and time zone:

        $ sudo dpkg-reconfigure locales
        $ sudo dpkg-reconfigure tzdata

- Make sure you have an updated installation and install `git`:

        $ sudo apt-get update
        $ sudo apt-get upgrade
        $ sudo apt-get install git

- Create new user for GW service and add it to sudoers

        $ sudo adduser mix 
        $ sudo adduser mix sudo

- To prevent the system asking root password regularly, add mix user in sudoers file

        $ sudo visudo

Add the line `mix ALL=(ALL) NOPASSWD: ALL`

:warning: Beware this allows a connected console with the ttn user to issue any
commands on your system, without any password control. This step is completely optional and remains your decision.

- Logout and login as `mix` and remove the default `pi` user

        $ sudo userdel -rf pi

- Configure the wifi credentials (check [here for additional details](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md))

        $ sudo nano /etc/wpa_supplicant/wpa_supplicant.conf 

And add the following block at the end of the file, replacing SSID and password to match your network:

                network={
                    ssid="The_SSID_of_your_wifi"
                    psk="Your_wifi_password"
                }
 
- Clone [the installer](https://github.com/heliance/lora_gw/) and start the installation

        $ git clone https://github.com/heliance/lora_gw.git ~/raspi-ic880a
        $ cd ~/raspi-ic880a
        $ sudo chmod +x ./install.sh
        $ sudo ./install.sh

- If you want to use the remote configuration option, please make sure you have created a JSON file named as your gateway EUI (e.g. `B827EBFFFE7B80CD.json`) in the [Gateway Remote Config repository](https://github.com/ttn-zh/gateway-remote-config). 
- **Big Success!** You should now have a running gateway in front of you!

# Credits

These scripts are largely based on the awesome work by [Ruud Vlaming](https://github.com/devlaam) on the [Lorank8 installer](https://github.com/Ideetron/Lorank).
