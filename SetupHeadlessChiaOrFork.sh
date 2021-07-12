#!/bin/bash
######################
#   VALUES TO EDIT   #
######################

# DISCLAIMER: Use at your own risk.

# PLEASE READ SECTION EXPLANATIONS:
# GLOBAL are values that MUST be filled.
# OPTIONAL are optional values
# FARMER are values that must be filled if your installType is 'farmer'
# TIMELORD are values that must be filled if your installType is 'timelord'
# [DO NOT TOUCH] Various helping things, DO NOT TOUCH! Unless you know what you are doing, *wink wink*
# timelord -> Installs the timelord and starts... timelording? Uses generic new mnemonic
# farmer -> Installs farmer and starts farming with the {plotsDirectory} value, using your mnemonic
installType="farmer"
if [ ! -z "$2" ]; then
	installType="$2"
fi
##########
# GLOBAL #
##########
# E.G. https://github.com/Chia-Network/chia-blockchain
gitUrl=""
if [ ! -z "$1" ]; then
	gitUrl="$1"
fi
# The path where you want your user home directory to be
# If unsure, don't touch
homePath="/home/"
# Enable testnet 1 or 0
# What is a testnet?
# If unsure, don't touch
enableTestnet="0"
#Backup the chain DB? If value is 1, where?
backupDB="1"
#Path where to backup the DB
backupDBPath="/root/"
#Usual name of chia and forks for blockchain DB
dbName="blockchain_v1_mainnet.sqlite"
#This will force answer yes to all questions when errors arise
forceInstall="0"

############
# OPTIONAL #
############
# The username you want to use to create the user that will setup and run the blockchain fork
# WARNING: This user will DELETED if exists [perform clean install]
# DO NOT USE YOUR MAIN USER!!!!!
# IF EMPTY IS DERIVED FROM BLOCKCHAIN NAME OF GIT URL
username=""
# The password tied to the username
# IF EMPTY IS USED A RANDOM 32 CHAR PASS LENGTH
password=""

##########
# FARMER #
##########

# Your 24 words passphrase
mnemonic=""
# The directories you want to automatically add for start farming
# You can insert multiple values with ("/path1" "/path2" "/path_etc")
declare -a plotsDirectories=( )

############
# TIMELORD #
############
# Nothing here, yet.


##################
# [DO NOT TOUCH] #
#    DERIVED     #
##################
# E.G. chia-blockchain, derives from gitUrl
folderChainName=$(echo "${gitUrl##*/}" | sed "s#.git##g")
backupDBFullPath="${backupDBPath}/${dbName}_$chainCommand"
userHomeDir="${homePath}/${username}"
blockchainDBPath=$(find "$userHomeDir" -name "$dbName" -type f | head -n 1)
venvDir="${homePath}/${username}/${folderChainName}/venv"
if [ -z "$username" ]; then
	username=$(echo "$folderChainName" | cut -d '-' -f 1 )
fi

if [ -z "$password" ]; then
	password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi
cpassword=$(perl -e "print crypt(\"$password\", \"salt\"),\"\n\"")

######################
#   [DO NOT TOUCH]   #
# COMMANDS DISCOVERY #
######################
bashCMD=$(which bash)

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
	if [ "$forceInstall" == "1" ]; then
		echo "User already exists! Forcing installation..."
	else
        	read -p "User $username already exists! By continuing you will delete ALL of $username files, do you want to proceed? [y/N] "  -r
        	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        	        echo "Oke no probs, bye bye"
        	        exit
        	fi
	fi
        echo "Killing user processes before deletion.."
        userId=$(id -u "$username")
        pkill -u $userId -9
        sleep 3s
	if [ "$backupDB" == "1" ]; then
		if [ ! -z "$blockchainDBPath" ] && [ -f "$blockchainDBPath" ]; then
			mv "$blockchainDBPath" "$backupDBFullPath"
		else
			warningHeader
			if  [ "$forceInstall" != "1" ]; then
				echo "Blockchain DB not found! Forcing installation..."
			else
				read -p "Blockchain DB not found! Do you want to continue? [y/N]" -r
	        		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	        		        echo "Oke no probs, bye bye"
	        		        exit
			        fi
			fi
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
useradd -s "$bashCMD" -m -p "$cpassword" "$username" -b "$homePath"
usermod -a -G sudo "$username"
#Git checkout
$asUser "git clone $gitUrl --recurse-submodules"
#Base Installation
$asUser "cd $folderChainName && sed -i \"s#sudo#sudo -S#g\" install.sh && echo \"$password\" | sh install.sh"
#Finds the chain command in the venv of the install dir
chainCommand=$(find "$venvDir/bin" -name "*_farmer" -type f | head -n 1 | xargs basename | cut -d '_' -f 1)

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
        #Adds plot directories to farmer
	for plotDirectory in "${plotsDirectories[@]}"
	do
	        $asUser "$goVenv && $chainCommand plots add -d \"$plotDirectory\""
	done
        #Adds your mnemonic keys to use for farming
        $asUser "$goVenv && echo $mnemonic | $chainCommand keys add"
        #Starts the farmer
        $asUser "$goVenv && $chainCommand start farmer"
fi
if [ "$backupDB" == "1" ]; then
	$asUser "$goVenv && $chainCommand stop all"
	mv "$backupDBFullPath" "$blockchainDBPath"
	$asUser "$goVenv && $chainCommand start $installType"
fi
