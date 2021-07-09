#!/bin/bash
# This script checks the existance of the blockchain source into users home directories
# If found, tries to deduce the command needed to start the farmer and starts it (killing previous daemon pid)
# Usage: Execute from root changing {homePath} var if needed, can be added in crontab or init systems or whatever

homePath="/home"
availableChains=$(find "$homePath" -mindepth 3 -maxdepth 3 -name "activate" -type l)
echo "$availableChains" | while read availableChain
do
        #If we have an available chain, we assume all of the below is available (unless some pretty heavy fork modification, in which case... godspeed)
        blockChainPath=$(dirname "$availableChain")
        venvDir=$(find "$blockChainPath" -name "venv" -type d -maxdepth 1 | head -n 1)
        chainExec=$(find "$venvDir/bin" -name "*_farmer" -type f | head -n 1 | xargs basename | cut -d '_' -f 1)
        chainDaemon="${chainExec}_daemon"
        userHomePath=$(dirname "$blockChainPath")
        userOfChain=$(basename "$userHomePath")
        daemonPid=$(ps aux | grep "$chainDaemon" | grep -v grep | awk ' { print $2 } ')
        if [ ! -z "$daemonPid" ]; then
                echo "Found old daemon pid $daemonPid, killing process..."
                kill $daemonPid
                #Hopefully enough, else TODO: loop and wait until gone
                sleep 10s
        fi
        sudo su - "$userOfChain" -c "source $availableChain && $chainExec start farmer"
done
