#!/bin/bash
# Offense Coin Masternode Setup Script V1.0.0 for Ubuntu LTS
#
# Script will attempt to autodetect primary public IP address
# and generate masternode private key unless specified in command line
#
# Usage:
# bash ofcauto.sh
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#TCP port
PORT=18171
RPC=18172

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'offense_coind' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop offense_coind${NC}"
        offense_coin-cli stop
        sleep 30
        if pgrep -x 'offense_coind' > /dev/null; then
            echo -e "${RED}offense_coind daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            sudo pkill -9 offense_coind
            sleep 30
            if pgrep -x 'offense_coind' > /dev/null; then
                echo -e "${RED}Can't stop offense_coind! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}

#Process command line parameters
genkey=$1
clear

echo -e "${GREEN} ------- Offense Coin MASTERNODE INSTALLER V1.0.0--------+
 |                                                  |
 |                                                  |::
 |       The installation will install and run      |::
 |        the masternode under a user OFC.         |::
 |                                                  |::
 |        This version of installer will setup      |::
 |           fail2ban and ufw for your safety.      |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::S${NC}"
echo "Do you want me to generate a masternode private key for you?[y/n]"
read DOSETUP

if [[ $DOSETUP =~ "n" ]] ; then
          read -e -p "Enter your private key:" genkey;
              read -e -p "Confirm your private key: " genkey2;
    fi

#Confirming match
  if [ $genkey = $genkey2 ]; then
     echo -e "${GREEN}MATCH! ${NC} \a" 
else 
     echo -e "${RED} Error: Private keys do not match. Try again or let me generate one for you...${NC} \a";exit 1
fi
sleep .5
clear

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi
if [ -d "/var/lib/fail2ban/" ]; 
then
    echo -e "${GREEN}Packages already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano
sudo apt-get install unzip
fi

#Generating Random Password for  JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi
 
#Installing Daemon
cd ~
rm -rf /usr/local/bin/offense_coin*
wget https://github.com/OFFENSE-COIN/Offense/releases/download/v1.0/Offense-1.0.0-ubuntu-daemon.tar.gz
tar -xzvf Offense-1.0.0-ubuntu-daemon.tar.gz
sudo chmod -R 755 offense_coin-cli
sudo chmod -R 755 offense_coind
cp -p -r offense_coind /usr/local/bin
cp -p -r offense_coin-cli /usr/local/bin

sudo mkdir ~/.offensecoin-params
cd ~/.offensecoin-params && wget https://github.com/OFFENSE-COIN/Offense/raw/master/params/sapling-output.params && wget https://github.com/OFFENSE-COIN/Offense/raw/master/params/sapling-spend.params
	
 offense_coin-cli stop
 sleep 5
 #Create datadir
 if [ ! -f ~/.offensecoin/offensecoin.conf ]; then 
 	sudo mkdir ~/.offensecoin
	
 fi

cd ~
clear
echo -e "${YELLOW}Creating offensecoin.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.offensecoin/offensecoin.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
server=1
daemon=1

EOF

    sudo chmod 755 -R ~/.offensecoin/offensecoin.conf

    #Starting daemon first time just to generate masternode private key
    offense_coind
sleep 7
while true;do
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    genkey=$(offense_coin-cli createmasternodekey)
    if [ "$genkey" ]; then
        break
    fi
sleep 7
done
    fi
    
    #Stopping daemon to create offensecoin.conf
    offense_coin-cli stop
    sleep 5
cd ~/.offensecoin && rm -rf blocks chainstate sporks
cd ~/.offensecoin && wget http://51.210.22.130/bootstrap.tar.gz
cd ~/.offensecoin && tar -xzvf bootstrap.tar.gz
sudo rm -rf ~/.offensecoin/bootstrap.tar.gz

	
# Create offensecoin.conf
cat <<EOF > ~/.offensecoin/offensecoin.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
rpcport=$RPC
port=$PORT
listen=1
server=1
daemon=1

logtimestamps=1
maxconnections=256
masternode=1
externalip=$publicip:$PORT

masternodeaddr=$publicip:$PORT
masternodeprivkey=$genkey
addnode=149.202.136.0
addnode=51.210.22.128
addnode=46.105.224.16
addnode=149.202.136.1
addnode=51.210.22.129
addnode=46.105.224.17
addnode=51.210.22.130
addnode=46.105.224.18
addnode=139.162.221.83
addnode=172.104.160.169
addnode=172.104.153.220
addnode=139.162.125.208
addnode=172.105.255.45

EOF
    offense_coind -daemon
#Finally, starting daemon with new offensecoin.conf
printf '#!/bin/bash\nif [ ! -f "~/.offensecoin/offensecoin.pid" ]; then /usr/local/bin/offense_coind -daemon ; fi' > /root/ofcauto.sh
chmod -R 755 /root/ofcauto.sh
#Setting auto start cron job for Offense Coin
if ! crontab -l | grep "ofcauto.sh"; then
    (crontab -l ; echo "*/5 * * * * /root/ofcauto.sh")| crontab -
fi

echo -e "========================================================================
${GREEN}Masternode setup is complete!${NC}
========================================================================
Masternode was installed with VPS IP Address: ${GREEN}$publicip${NC}
Masternode Private Key: ${GREEN}$genkey${NC}
Now you can add the following string to the masternode.conf file 
======================================================================== \a"
echo -e "${GREEN}OFC_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
echo -e "========================================================================
Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it 
into your ${GREEN}masternode.conf${NC} file and replace:
    ${GREEN}OFC_mn1${NC} - with your desired masternode name (alias)
    ${GREEN}TxId${NC} - with Transaction Id from getmasternodeoutputs
    ${GREEN}TxIdx${NC} - with Transaction Index (0 or 1)
     Remember to save the masternode.conf and restart the wallet!
To introduce your new masternode to the Offense Coin network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'Is Synced' status will change
to 'true', which will indicate a comlete sync, although it may take
from several minutes to several hours depending on the network state.
Your initial Masternode Status may read:
    ${GREEN}Node just started, not yet activated${NC} or
    ${GREEN}Node  is not in masternode list${NC}, which is normal and expected.
"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}
Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in offensecoin.conf:
${GREEN}cat ~/.offensecoin/offensecoin.conf${NC}
Here is your offensecoin.conf generated by this script:
-------------------------------------------------${GREEN}"
echo -e "${GREEN}OFC_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
cat ~/.offensecoin/offensecoin.conf
echo -e "${NC}-------------------------------------------------
NOTE: To edit offensecoin.conf, first stop the offense_coind daemon,
then edit the offensecoin.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the offense_coind daemon back up:
to stop:              ${GREEN}offense_coin-cli stop${NC}
to start:             ${GREEN}offense_coind${NC}
to edit:              ${GREEN}nano ~/.offensecoin/offensecoin.conf${NC}
to check mn status:   ${GREEN}offense_coin-cli getmasternodestatus${NC}
========================================================================
To monitor system resource utilization and running processes:
                   ${GREEN}htop${NC}
========================================================================
"