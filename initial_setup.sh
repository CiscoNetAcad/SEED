#!/bin/bash
# Initial Setup for the "SEED - Virtual infrastructure for penetration testing using RPI" Lab
# Copyright 2018 Cisco Networking Academy
# Author Mihai Chiroiu
# The script will install all required software on a RASPBIAN STRETCH LITE image
#
#To use this script graphically, make it executable (Right Click File, Permissions, Select Execute Checkbox)
#then double click the file and select "Run in Terminal"
#
#Raspberry Pi, Raspbian, and Stretch are trademarks of their respective owners.  No endorsement by any trademark holder is stated or implied.
CDATE="2018"
VERSION="_0_1"
DISTRIBUTION="stretch"
RED="\033[0;31m"
GREEN="\033[1;32m"
ENDCOLOR="\033[0m"
ARCHITECTURE=`uname -m`  #armv61 & armv71
CODENAME=$(lsb_release -cs)
USER=$(whoami)
INSIDE=eth0
BRIDGE=sw0
MGMT=wlan0
clear
echo -e  $GREEN"Initial Setup for \"SEED - Virtual infrastructure for penetration testing using RPI\" lab, version $VERSION\nCopyright 2018-$CDATE Cisco Networking Academy.\nAll rights resereved.\nRun this script in a terminal.\nThis script adds software from sources which are not under its control.\nNo warranty or guarantee of suitability exists for this software.\nUse at your own risk.\n\n"$ENDCOLOR
##############################  Verify Distribution
if [ $CODENAME != $DISTRIBUTION ]
then
	echo -e  $RED"Sorry, you are using $CODENAME.  Only Raspbian $DISTRIBUTION is supported.\n\nYou may attempt to edit line 15 of this script to reflect your distribution."$ENDCOLOR
	read -sn 1 -p "Press any key to terminate."
	echo -e "\n"
	exit 1
fi
##############################  Verify Chipset Architecture
if [ $ARCHITECTURE != "armv6l" ]
then
	if [ $ARCHITECTURE != "armv7l" ]
	then
	    echo -e  $RED"Sorry, only armv6l and armv7l chipset architectures are supported."$ENDCOLOR
	    sleep 5
	    exit 1
	fi
fi
############################## Verify two more network connections
PORTNUMBER=$(ip add | grep "<" | grep -v "lo" | cut -d' ' -f2 | cut -d':' -f1 | wc -w )
if (( $PORTNUMBER > 1 ))
then
    if (( $PORTNUMBER > 2 ))
    then
        echo -e $RED"Three or more network interfaces available.  You must use exactly two."$ENDCOLOR
        #exit 1
    else
    	echo -e $GREEN"Two network interfaces verified."$ENDCOLOR
    fi
else
	echo -e $RED"You must attach a USB wireless card to make this Pi a router."$ENDCOLOR
	exit 1
fi
############################## Verify connection to Internet
TESTCONNECTION=`wget --tries=3 --timeout=15 www.google.com -O /tmp/testinternet &>/dev/null 2>&1`
if [ $? != 0 ]
then
  echo -e $RED"This Pi has local network access only."$ENDCOLOR
  exit 1
else
  echo -e $GREEN"Internet connection verified."$ENDCOLOR
fi
############################## Make sure that no other process is installing packages
while ps -U root -u root u | grep "apt" | grep -v grep > /dev/null;
       do
       echo -e $RED"Installation can't continue. Please wait for apt to finish running, or terminate the process, then try again."$ENDCOLOR
       read -sn 1 -p "Press any key to continue…"
done       
while ps -U root -u root u | grep "dpkg" | grep -v grep > /dev/null;
       do 
       echo -e $RED"Installation can't continue. Wait for dpkg to finish running, or exit it, then try again."$ENDCOLOR
       read -sn 1 -p "Press any key to continue…"
done  
############################## Continue?
echo -e $RED"Root access is required for this program to work."$ENDCOLOR
echo -e $RED"The Raspberry Pi must be rebooted at the end of installation."$ENDCOLOR
echo -e $GREEN"Do you wish to continue? (y/n)"$ENDCOLOR
read -sn 1 CONTINUE
if [[ $CONTINUE == "y" ]] || [[ $CONTINUE == "y" ]]
then
	echo -e $GREEN"Continuing installation."$ENDCOLOR
else
	echo -e $RED"Program terminated."$ENDCOLOR
	exit 1
fi
##############################  Install the required software for the project
ARCHVERSION='uname -r'
sudo apt-get update
sudo apt-get upgrade -y
if [ $ARCHVERSION != $((uname -r)) ]
then
  echo -e $RED"Rebooting now…"$ENDCOLOR
  sleep 5
  sudo reboot
fi
sudo apt -y install dnsmasq vim virtualenv htop git python-pip bridge-utils conntrack
#mininet install
git clone git://github.com/mininet/mininet
cd mininet
cat >> mininet.patch <<EOF
diff --git a/util/install.sh b/util/install.sh
index 2415324..3e38152 100755
--- a/util/install.sh
+++ b/util/install.sh
@@ -61,6 +61,7 @@ if which lsb_release &> /dev/null; then
     RELEASE=`lsb_release -rs`
     CODENAME=`lsb_release -cs`
 fi
+[ "$DIST" = "Raspbian" ] && DIST=Debian
 echo "Detected Linux distribution: $DIST $RELEASE $CODENAME $ARCH"

 # Kernel params
EOF
patch -p1 < mininet.patch
sudo ./util/install.sh -a
cd ..
rm -rf mininet oflops  oftest  openflow  pox
#docker install
curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm -rf get-docker.sh
#the required archives for the project
tar xvf seed.tar
cd seed
make venv
make containers
cd ..
##############################	Set the IP address range for the internal network
ETHBRIDGEIP="10.255.255.249/24"
ETHBRIDGEGWIP="10.255.255.249"
ETHFIRST="10.255.255.200"
ETHLAST="10.255.255.254"
ETHDHCPBROADCAST="10.255.255.255"
ETHSUBNET="10.255.255.0"
ETHMASK="255.255.255.0"
ETHNET="10.0.0.0/8" #create a route for the whole infrastructure using DHCP
ETHDNS="8.8.8.8"
##############################	Create a system service to manually set the IP address
##############################	This is a hack due to lack of persistent address support
echo -e "[Unit]" > ./seedapp.service
echo -e "Description=SEED Hackable RPI infrastructure service" >> ./seedapp.service
echo -e "Before=network-pre.target" >> ./seedapp.service
echo -e "Wants=network-pre.target" >> ./seedapp.service
echo -e "[Install]" >> ./seedapp.service
echo -e "WantedBy=multi-user.target" >> ./seedapp.service
echo -e "[Service]" >> ./seedapp.service
echo -e "User=root" >> ./seedapp.service
echo -e "Group=root" >> ./seedapp.service
echo -e "ExecStart=/home/pi/seed/.venv/bin/python2 /home/pi/seed/run_dev.py" >> ./seedapp.service
echo -e "ExecStartPost=/bin/sleep 5" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/brctl addif $BRIDGE $INSIDE" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/ip a flush $BRIDGE" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/ip a a $ETHBRIDGEIP dev $BRIDGE" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/ip r a 10.7.6.0/24 via 10.255.255.2" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/ip r a 10.88.205.0/24 via 10.255.255.1" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/ip r a 10.155.20.0/24 via 10.255.255.4" >> ./seedapp.service
echo -e "ExecStartPost=/sbin/ip r a 10.5.140.0/24 via 10.255.255.4" >> ./seedapp.service
echo -e "ExecStopPost=/sbin/brctl delif $BRIDGE $INSIDE" >> ./seedapp.service
echo -e "ExecStopPost=/sbin/ip a flush $BRIDGE" >> ./seedapp.service
echo -e "Restart=on-failure" >> ./seedapp.service
sudo mv ./seedapp.service /etc/systemd/system/seedapp.service
sudo systemctl enable seedapp.service
sudo systemctl start seedapp.service
##############################	Setup forwarding before updating
cp /etc/sysctl.conf ./
echo -e "net.ipv4.ip_forward=1" >> sysctl.conf
echo -e "net.bridge.bridge-nf-call-ip6tables=0" >> sysctl.conf
echo -e "net.bridge.bridge-nf-call-iptables=0" >> sysctl.conf
echo -e "net.bridge.bridge-nf-call-arptables=0" >> sysctl.conf
sudo mv ./sysctl.conf /etc/sysctl.conf
sudo iptables -F
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0
sudo sysctl -w net.bridge.bridge-nf-call-arptables=0
##############################	Setup DHCP forwarding
sudo echo -e "" > /var/lib/misc/dnsmasq.leases
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq
echo -e "local=/seed/" > ./dnsmasq.conf
echo -e "domain=seed" >> ./dnsmasq.conf
echo -e "no-hosts" >> ./dnsmasq.conf
echo -e "interface=$BRIDGE" >> ./dnsmasq.conf
echo -e "dhcp-range=$ETHFIRST,$ETHLAST,$ETHSUBNET,24h" >> ./dnsmasq.conf
echo -e "dhcp-option=1,$ETHMASK" >> ./dnsmasq.conf 
echo -e "dhcp-option=3" >> ./dnsmasq.conf	#no gateway
echo -e "dhcp-option=6" >> ./dnsmasq.conf	#no dns
echo -e "dhcp-option=121,$ETHNET,$ETHBRIDGEGWIP" >> ./dnsmasq.conf	#route to virtual infrastructure
sudo mv ./dnsmasq.conf /etc/dnsmasq.conf
##############################	Reboot the Pi
#echo -e $RED"Rebooting now…"$ENDCOLOR
#sudo sleep 2
#sudo systemctl reboot
