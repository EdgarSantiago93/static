#!/usr/bin/env bash

DTOVERLAY="dtoverlay=dwc2"
UART="enable_uart=1"
MODULESLOAD="modules-load=dwc2,g_ether"
IPV6DISABLE="ipv6.disable=1"

LISTENER="listener 1883"
ALLOW_ANONYMOUS="allow_anonymous true"

echo ""
echo "//////////////////////////////////////////////////"
echo "/////////////////////////////////////////////&////"
echo "//////////////////////////////(#(//////////@@@@%//"
echo "///////////////&@@@@@@%///@@@/////@@&///////&@////"
echo "////////////@@@////////@@&//////////@@@///////////"
echo "///////(@@@@//////////////@@@@@////////@@@@@//////"
echo "//////////////////////////////////////////////////"
echo "//@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@/"
echo "/////@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(////"
echo "///////#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%///////"
echo "////////(@@@@@@@&/&@@@@@//@@@@@@//@@@@@@@#////////"
echo "/////////%@@@@@@&/&@@@@@//@@@@@@//@@@@@@@/////////"
echo "//////////@@@@@@&/&@@@@@//@@@@@@//@@@@@@//////////"
echo "///////////@@@@@@/@@@@@@(/@@@@@@/#@@@@@///////////"
echo "///////////(@@@@@@@@@@@@@@@@@@@@@@@@@@////////////"
echo "/////////////(@@@@@@@@@@@@@@@@@@@@@@//////////////"
echo "//////////////////////////////////////////////////"                  
echo ""
echo " _________________________________ "
echo "|  _____________________________  |"
echo "| |                             | |"
echo "| | Tumble initial setup script | |"
echo "| |_____________________________| |"
echo "|_________________________________|"

echo ""
echo ""

echo "👾 -> Updating config.txt <- 👾 "

DTCHECK=$(awk '/dtoverlay=dwc2/' /boot/config.txt)
UARTCHECK=$(awk '/enable_uart=1/' /boot/config.txt)


if [ "$DTCHECK" = "$DTOVERLAY" ]; then
    echo "⏭️ -> Dtoverlay already exists in config.txt, skipping"
else
    echo "✅ -> Adding dtoverlay setting to config.txt"
    sudo echo "$DTOVERLAY" | tee -a /boot/config.txt
fi

if [ "$UARTCHECK" = "$UART" ]; then
    echo "⏭️ -> Uart setting already exists in config.txt, skipping"
else
    echo "✅ -> Adding uart setting to config.txt"
    sudo echo "$UART" | tee -a /boot/config.txt
fi

echo "\n"
echo "👾 -> Updating cmdline.txt <- 👾 "

MODULESCHECK=$(sed -e '/modules-load=dwc2,g_ether/!d' /boot/cmdline.txt)
IPV6CHECK=$(awk '/ipv6.disable=1/' /boot/cmdline.txt)

if [ "$MODULESCHECK" = "" ]; then
    echo "✅ -> Adding module-load to cmdline.txt"
    sudo echo "$MODULESLOAD" | tee -a /boot/cmdline.txt
else
    echo "⏭️ -> Module-load setting already exists in cmdline.txt, skipping"    
fi


if [ "$IPV6CHECK" = "" ]; then
    echo "✅ -> Adding disable-ipv6 to cmdline.txt"
    sudo echo "$IPV6DISABLE" | tee -a /boot/cmdline.txt
else
    echo "⏭️ -> Disable ipv6 setting already exists in cmdline.txt, skipping"    
fi


echo "\n"

echo "👾 -> Update <- 👾"
echo "✅ -> Updating and upgrading packages"
sudo apt update && sudo apt upgrade
echo "\n"


echo "👾 -> Packages <- 👾"
echo "✅ -> Installing mosquitto client"
sudo apt install -y mosquitto mosquitto-clients

echo "\n"
echo "✅ -> Enabling mosquitto service"
sudo systemctl enable mosquitto.service

MOSQUITTOSTATUS=$(systemctl status mosquitto.service | grep Active: | awk '{print $2$3}')

LISTENERCHECK=$(awk '/listener 1883/' /etc/mosquitto/mosquitto.conf)
ALLOWANONCHECK=$(awk '/allow_anonymous true/' /etc/mosquitto/mosquitto.conf)


if [ $MOSQUITTOSTATUS = 'active(running)' ]; then
  echo "✅ -> Mosquitto service is active and running"

if [ "$LISTENERCHECK" = "$LISTENER" ]; then
    echo "⏭️ -> Listener setting already exists in mosquitto.conf, skipping"
else
    echo "✅ -> Adding listener setting to mosquitto.txt"
    sudo echo "$LISTENER" | tee -a /etc/mosquitto/mosquitto.conf
fi

if [ "$ALLOWANONCHECK" = "$ALLOW_ANONYMOUS" ]; then
    echo "⏭️ -> Allow anonymous setting already exists in mosquitto.conf, skipping"
else
    echo "✅ -> Adding allow anonymous setting to mosquitto.txt"
    sudo echo "$ALLOW_ANONYMOUS" | tee -a /etc/mosquitto/mosquitto.conf
fi
fi

echo "\n"
echo "🔃 -> Restarting mosquitto service"
sudo systemctl restart mosquitto.service

MOSQUITTOSTATUSAFTER=$(systemctl status mosquitto.service | grep Active: | awk '{print $2$3}')

if [ $MOSQUITTOSTATUS = 'active(running)' ]; then
  echo "\n"
  echo "✅ -> Mosquitto service is up and running"
  echo "\n"
fi
# check status

echo "👾 -> Config folder <- 👾"
echo "✅ -> Created config folder @ /home/pi/config"
mkdir -p /home/pi/config
echo "\n"

echo "👾 -> Creating startup scripts <- 👾"

mkdir -p /home/pi/startScripts
echo "✅ -> Created startScripts folder @ /home/pi/startScripts"
# Create the script
sudo tee /home/pi/startScripts/mosquittoServiceStatusCheck.sh <<'BASH'
#!/usr/bin/env bash

version="v0.1"
CURRENT_DIR="$(pwd)"
SCRIPTNAME="${0##*/}"
exec 1>/tmp/mosquittoStatus.log 2>&1  
set -x
set -e

echo '||-> Checking for service status'

mosquittoStatus=$(systemctl status mosquitto.service | grep Active: | awk '{print $2$3}')
if [ $mosquittoStatus != 'active(running)' ]; then
  echo '||-> Service not running, attempting restart'
 sudo systemctl enable mosquitto.service
fi
 
echo $mosquittoStatus
BASH
sudo chmod +x /home/pi/startScripts/mosquittoServiceStatusCheck.sh

echo "✅ -> Mosquitto service status check script created @ /home/pi/startScripts/mosquittoServiceStatusCheck.sh"
echo "\n"

# Create the initial pi start script
sudo tee /home/pi/startScripts/reinitApp.sh <<'BASH'
#!/usr/bin/env bash
version="v0.1"
CURRENT_DIR="$(pwd)"
SCRIPTNAME="${0##*/}"
exec 1>/tmp/restartApp.log 2>&1  
set -x
set -e
echo '||-> Restarting pi controller'
pm2 delete picontroller
cd /home/pi/pi-controller
pm2 start src/index.js --name picontroller
pm2 save
BASH
sudo chmod +x /home/pi/startScripts/reinitApp.sh

echo "✅ -> The script that restarts a fresh instance of the app on reboot was created @ /home/pi/startScripts/reinitApp.sh"
echo ""

echo "👾 -> Rewriting Rc.local file <- 👾"
echo "🚨 -> Switching to root user"
whoami
sudo -i -u root bash << EOF
> /etc/rc.local
echo '#!/bin/sh -e' | tee -a /etc/rc.local
echo '#' | tee -a /etc/rc.local
echo '# rc.local' | tee -a /etc/rc.local
echo '#' | tee -a /etc/rc.local
echo '# This script is executed at the end of each multiuser runlevel.' | tee -a /etc/rc.local
echo '# Make sure that the script will "exit 0" on success or any other' | tee -a /etc/rc.local
echo '# value on error.' | tee -a /etc/rc.local
echo '#' | tee -a /etc/rc.local
echo '# In order to enable or disable this script just change the execution' | tee -a /etc/rc.local
echo '# bits.' | tee -a /etc/rc.local
echo '#' | tee -a /etc/rc.local
echo '# By default this script does nothing.' | tee -a /etc/rc.local
echo '' | tee -a /etc/rc.local
echo '# Print the IP address' | tee -a /etc/rc.local
echo '_IP=$(hostname -I) || true' | tee -a /etc/rc.local
echo 'if [ "$_IP" ]; then' | tee -a /etc/rc.local
echo '  printf "My IP address is %s\n" "$_IP"' | tee -a /etc/rc.local
echo 'fi' | tee -a /etc/rc.local
echo '' | tee -a /etc/rc.local
echo "sudo bash /home/pi/startScripts/mosquittoServiceStatusCheck.sh" | tee -a /etc/rc.local
echo "sudo bash /home/pi/startScripts/reinitApp.sh" | tee -a /etc/rc.local
echo "sudo systemctl start ssh" | tee -a /etc/rc.local
echo 'exit 0' | tee -a /etc/rc.local
sudo chmod +x /etc/rc.local
EOF
echo "✅ -> Rc.local file rewritten"
sudo chmod +x /etc/rc.local

echo ""


echo "👾 -> Installing node <- 👾"

# install node 
curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -
sudo apt-get update
sudo apt-get install -y nodejs
echo "✅ -> Node instaled"
echo "🧞‍♂️ -> Node version " $(node --version)


# INSTALL PM2

echo ""
echo "👾 -> Installing PM2 <- 👾"
echo "🚨 -> Switching to root user"
whoami
sudo -i -u root bash << EOF
npm install -g pm2
EOF
pm2
echo "✅ -> Pm2 installed"
echo "🧞‍♂️ -> PM2 version " $(pm2 --version)
echo "⬅️ -> Switched back to pi user"


echo "✅ -> Running PM2 startup scripts"
pm2 startup
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u pi --hp /home/pi

echo ""
echo ""
echo ""



echo "👾 -> SUMMARY <- 👾"

SC1=$([ -f /home/pi/startScripts/mosquittoServiceStatusCheck.sh ] && echo "Mosquitto script exist." || echo "Mosquitto script does NOT exist.")
SC2=$([ -f /home/pi/startScripts/reinitApp.sh ] && echo "App restart script exist." || echo "App restart script does NOT exist.")
MOSQUITTOSTATUSFINAL=$(systemctl status mosquitto.service | grep Active: | awk '{print $2$3}')

echo ""
echo "🏁 -> config.txt modified"
echo "🏁 -> cmdline.txt modified"
echo "🏁 -> rc.local rewritten (scripts and ssh service)"
echo "🏁 -> Packages updated and upgraded"
echo "🏁 -> Script: $SC1"
echo "🏁 -> Script: $SC2"
echo "🏁 -> Mosquitto broker installed $(mosquitto -h | head -1 | awk '{print $3}')"
echo "🏁 -> Mosquitto status: $MOSQUITTOSTATUSFINAL"
echo "🏁 -> Node installed" $(node --version)
echo "🏁 -> Pm2 installed" $(pm2 --version)

echo ""
echo "#HERE WE GO!🏈"
echo ""

echo "*********"
echo "Initial setup is done, please clone the app to this device and run the following commands after reboot:"
echo "- cd /home/pi/pi-controller"
echo '- pm2 start src/index.js --name "picontroller"'
echo "- pm2 save"
echo "*********"

echo ""
echo ""
echo ""
while true; do
    read -p "Do you wish to reboot now? [Yy/Nn] " yn
    case $yn in
        [Yy]* ) sudo reboot now; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no. [Y/N]";;
    esac
done



