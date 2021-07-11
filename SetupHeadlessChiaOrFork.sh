#!/bin/bash
######################
#   VALUES TO EDIT   #
######################

# DISCLAIMER: Use at your own risk.

# PLEASE READ SECTION EXPLANATIONS:
# GLOBAL are values that MUST be filled.
# FARMER are values that must be filled if your installType is 'farmer'
# TIMELORD are values that must be filled if your installType is 'timelord'
# [DO NOT TOUCH] Various helping things, DO NOT TOUCH! Unless you know what you are doing, *wink wink*
# timelord -> Installs the timelord and starts... timelording? Uses generic new mnemonic
# farmer -> Installs farmer and starts farming with the {plotsDirectory} value, using your mnemonic
installType="timelord"

##########
# GLOBAL #
##########
# The username you want to use to create the user that will setup and run the blockchain fork
# WARNING: This user will DELETED if exists [perform clean install]
# DO NOT USE YOUR MAIN USER!!!!!
username=""
# The password tied to the username
password=""
# E.G. https://github.com/Chia-Network/chia-blockchain
gitUrl=""
# E.G. chia uses command 'chia' to run ... commands...
chainCommand=""
# The path where you want your user home directory to be
# If unsure, don't touch
homePath="/home/"
# Enable testnet 1 or 0
# What is a testnet?
# If unsure, don't touch
enableTestnet="0"
#Backup the chain DB? If value is 1, where?
backupDB="0"
#Path where to backup the DB
backupDBPath="/root/"
#Usual name of chia and forks for blockchain DB
dbName="blockchain_v1_mainnet.sqlite"

##########
# FARMER #
##########

# Your 24 words passphrase
mnemonic=""
# The directory you want to automatically add for start farming
# TODO: Allow multiple values
plotsDirectory=""

############
# TIMELORD #
############
# Nothing here, yet.


################### [DO NOT TOUCH] #
#    DERIVED     #
##################
# E.G. chia-blockchain, derives from gitUrl
folderChainName=$(echo "${gitUrl##*/}" | sed "s#.git##g")
backupDBFullPath="${backupDBPath}/${dbName}_$chainCommand"
blockchainDBPath=""
##################
# [DO NOT TOUCH] #
#    HELPERS     #
##################
function warningHeader {
        echo "#############"
        echo "#  WARNING  #"
        echo "#############"
}

function errorHeader {
        echo "###########"
        echo "#  ERROR  #"
        echo "###########"
}

##################
# [DO NOT TOUCH] #
#  SETUP START   #
##################

userExist=$(cat /etc/shadow | grep $username)
#TODO: Generalize for OSs without apt
apt update && apt install wget curl python3-dev python3-venv python3-pip rsync git bc lsb-release sudo  -y

#TODO: While loop with true and check iterations for I/O stalled processes who believe themselves to be highlanders
if [ ! -z "$userExist" ]; then
        warningHeader
        read -p "User $username already exists! By continuing you will delete ALL of $username files, do you want to proceed? [y/N] "  -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Oke no probs, bye bye"
                exit
        fi
        echo "Killing user processes before deletion.. If you see a failure it's ok, means no processes were running"
        userId=$(id -u "$username")
        pkill -u $userId -9
        sleep 3s
	userHomeDir=$(eval echo "~$username")
	if [ "$backupDB" == "1" ]; then
		blockchainDBPath=$(find "$userHomeDir" -name "$dbName" -type f)
		if [ ! -z "$blockchainDBPath" ]; then
			#TODO: Check for available space? Use rsync?
			mv "$blockchainDBPath" "$backupDBFullPath"
		fi
	fi
        deluser $username
fi
userExist=$(cat /etc/shadow | grep $username)
if [ ! -z "$userExist" ]; then
        errorHeader
        echo "User deletion failed! No clue as to why..."
        exit
fi
if [ -d "$homePath/$username" ]; then
        rm -rf "$homePath/$username"
fi
asUser="sudo su - $username -c "
goVenv="cd $folderChainName && . ./activate "
cpassword=$(perl -e "print crypt(\"$password\", \"salt\"),\"\n\"")
useradd -s "/usr/bin/bash" -m -p "$cpassword" "$username" -b "$homePath"
usermod -a -G sudo "$username"
#Git checkout
$asUser "git clone $gitUrl --recurse-submodules"
#Base Installation
$asUser "cd $folderChainName && sed -i \"s#sudo#sudo -S#g\" install.sh && echo \"$password\" | sh install.sh"

#Configuration based on install type
if [ "$installType" == "timelord" ]; then
        #Allows sudo to receive password from stdin
        $asUser "$goVenv && sed -i \"s#sudo#sudo -S#g\" install-timelord.sh"
        #Installs the timelord
        $asUser "$goVenv && echo \"$password\" | sh install-timelord.sh"
        #Initializes local config files
        $asUser "$goVenv && $chainCommand init"
        #Configures testnet if needed
	if [ "$enableTestnet" == "1" ]; then
		$asUser "$goVenv && $chainCommand configure -t t"
	fi
        #Creates random keys
        $asUser "$goVenv && $chainCommand keys generate"
        #Starts the timelord
        $asUser "$goVenv && $chainCommand start timelord"
fi
if [ "$installType" == "farmer" ]; then
        #Initializes local config files
        $asUser "$goVenv && $chainCommand init"
        #Configures testnet if needed
        if [ "$enableTestnet" == "1" ]; then
                $asUser "$goVenv && $chainCommand configure -t t"
        fi
        #Adds plot directory to farmer
        $asUser "$goVenv && $chainCommand plots add -d \"$plotsDirectory\""
        #Adds your mnemonic keys to use for farming
        $asUser "$goVenv && echo $mnemonic | $chainCommand keys add"
        #Starts the farmer
        $asUser "$goVenv && $chainCommand start farmer"
	#Starts the wallet so that it syncs as the blockchain db gets downloaded
	$asUser "$goVenv && echo S | $chainCommand wallet show"
fi
if [ "$backupDB" == "1" ]; then
	blockchainDBParentPath=$(basename "$blockchainDBPath")
	mkdir -p "$blockchainDBParentPath"
	mv "$backupDBFullPath" "$blockchainDBPath"
fi
