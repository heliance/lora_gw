#!/bin/bash

# Stop on the first sign of trouble.
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

VERSION="master"
if [[ $1 != "" ]]; then VERSION=$1; fi

echo "Avalcom LoRa GW installer"
echo "Version $VERSION"

# Update the gateway installer to the correct branch (defaults to master).
echo "Updating installer files..."
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
    echo "New installer found. Restarting process..."
    exec "./install.sh" "$VERSION"
fi

# Request gateway configuration data
# There are two ways to do it, manually specify everything
# or rely on the gateway EUI and retrieve settings files from remote (recommended).
echo "Gateway configuration:"

# Try to get gateway ID from MAC address.
# First try eth0, if that does not exist, try wlan0 (for RPi Zero).
GATEWAY_EUI_NIC="eth0"
if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
    GATEWAY_EUI_NIC="wlan0"
fi

if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
    echo "ERROR: No network interface found. Cannot set gateway ID."
    exit 1
fi

GATEWAY_EUI=$(ip link show $GATEWAY_EUI_NIC |
awk '/ether/ {print $2}' | awk -F\: '{print $1$2$3"FFFE"$4$5$6}')
GATEWAY_EUI=${GATEWAY_EUI^^} # to upper.

echo "Detected EUI $GATEWAY_EUI from $GATEWAY_EUI_NIC"

#read -r -p "Do you want to use remote settings file? [y/N]" response
#response=${response,,} # to lower
#
#if [[ $response =~ ^(yes|y) ]]; then
#    NEW_HOSTNAME="ava-lora-gw"
#    REMOTE_CONFIG=true
#else
printf "       Host name [ava-lora-gw]:"
read NEW_HOSTNAME
if [[ $NEW_HOSTNAME == "" ]]; then NEW_HOSTNAME="ava-lora-gw"; fi

printf "       Descriptive name [raspi-ic880a]:"
read GATEWAY_NAME
if [[ $GATEWAY_NAME == "" ]]; then GATEWAY_NAME="raspi-ic880a"; fi

printf "       Contact email: "
read GATEWAY_EMAIL

printf "       Latitude [0]: "
read GATEWAY_LAT
if [[ $GATEWAY_LAT == "" ]]; then GATEWAY_LAT=0; fi

printf "       Longitude [0]: "
read GATEWAY_LON
if [[ $GATEWAY_LON == "" ]]; then GATEWAY_LON=0; fi

printf "       Altitude [0]: "
read GATEWAY_ALT
if [[ $GATEWAY_ALT == "" ]]; then GATEWAY_ALT=0; fi
#fi


# Change hostname if needed.
CURRENT_HOSTNAME=$(hostname)

if [[ $NEW_HOSTNAME != $CURRENT_HOSTNAME ]]; then
    echo "Updating hostname to '$NEW_HOSTNAME'..."
    hostname $NEW_HOSTNAME
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/" /etc/hosts
fi

# Check tools.
echo "Installing required tools..."
apt-get install gcc make

#Check dependencies.
echo "Installing dependencies..."
apt-get install swig libftdi-dev python-dev

# Install LoRaWAN packet forwarder repositories.
INSTALL_DIR="/opt/ava-lora-gw"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR

# Build libraries
if [ ! -d libmpsse ]; then
    git clone https://github.com/devttys0/libmpsse.git
    pushd libmpsse/src
else
    pushd libmpsse/src
    git reset --hard
    git pull
fi

./configure --disable-python
make
make install
ldconfig

popd

# Build LoRa gateway app.
if [ ! -d lora_gateway ]; then
    git clone -b master https://github.com/heliance/lora_gateway.git
    pushd lora_gateway
else
    # For future needs.
    pushd lora_gateway
    git fetch origin
    git checkout legacy
    git reset --hard
fi

cp ./libloragw/99-libftdi.rules /etc/udev/rules.d/99-libftdi.rules

sed -i -e 's/CFG_SPI= native/CFG_SPI= ftdi/g' ./libloragw/library.cfg
sed -i -e 's/PLATFORM= kerlink/PLATFORM= lorank/g' ./libloragw/library.cfg
sed -i -e 's/ATTRS{idProduct}=="6010"/ATTRS{idProduct}=="6014"/g' /etc/udev/rules.d/99-libftdi.rules

make all

popd

# Build packet forwarder.
if [ ! -d packet_forwarder ]; then
    git clone -b master https://github.com/heliance/packet_forwarder.git
    pushd packet_forwarder
else
    # For future needs.
    pushd packet_forwarder
    git fetch origin
    git checkout legacy
    git reset --hard
fi

make all

popd

# Symlink poly packet forwarder.
if [ ! -d bin ]; then mkdir bin; fi
if [ -f ./bin/poly_pkt_fwd ]; then rm ./bin/poly_pkt_fwd; fi
ln -s $INSTALL_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd ./bin/poly_pkt_fwd
cp -f ./packet_forwarder/lora_pkt_fwd/global_conf.json ./bin/global_conf.json

LOCAL_CONFIG_FILE=$INSTALL_DIR/bin/local_conf.json

# Remove old config file.
# if [ -e $LOCAL_CONFIG_FILE ]; then rm $LOCAL_CONFIG_FILE #; fi;

#if [ "$REMOTE_CONFIG" = true ] ; then
#    # Get remote configuration repo. Need to update or remove.
#    if [ ! -d gateway-remote-config ]; then
#        git clone https://github.com/ttn-zh/gateway-remote-config.git
#        pushd gateway-remote-config
#    else
#        pushd gateway-remote-config
#        git pull
#        git reset --hard
#    fi
#
#    ln -s $INSTALL_DIR/gateway-remote-config/$GATEWAY_EUI.json $LOCAL_CONFIG_FILE
#
#    popd
#else
#    echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\": \"$GATEWAY_EUI\",
#    \n\t\t\"servers\": [ { \"server_address\": \"localhost\",
#     \"serv_port_up\": 1680, \"serv_port_down\": 1680, \"serv_enabled\": true } ],
#     \n\t\t\"ref_latitude\": $GATEWAY_LAT,\n\t\t\"ref_longitude\": $GATEWAY_LON,
#     \n\t\t\"ref_altitude\": $GATEWAY_ALT,\n\t\t\"contact_email\": \"$GATEWAY_EMAIL\",
#     \n\t\t\"description\": \"$GATEWAY_NAME\" \n\t}\n}" >$LOCAL_CONFIG_FILE
#fi

popd

echo
echo "Gateway EUI is: $GATEWAY_EUI"
echo "The hostname is: $NEW_HOSTNAME"
echo
echo "Installation completed."

# Start packet forwarder as a service
cp ./start.sh $INSTALL_DIR/bin/
cp ./lora-gateway.service /lib/systemd/system/
systemctl enable lora-gateway.service
chmod +x $INSTALL_DIR/bin/start.sh

echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now
