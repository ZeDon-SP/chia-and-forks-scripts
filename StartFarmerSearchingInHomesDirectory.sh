#!/bin/bash
# This script checks the existance of the blockchain source into users home directories
# If found, tries to deduce the command needed to start the farmer and starts it (killing previous daemon pid)
# TODO: Checks for availability of commands and present user errors.

homePath="/home"
availableChains=$(find "$homePath" -mindepth 3 -maxdepth 3 -name "activate" -type l)
echo "$availableChains" | while read availableChain
do
        blockChainPath=$(dirname "$availableChain")
        blockChainName=$(basename "$blockChainPath")
        chainProbableExec=$(cut -d '-' -f 1 <<< "$blockChainName")
        userHomePath=$(dirname "$blockChainPath")
        userOfChain=$(basename "$userHomePath")
        chainProbableDaemon="${chainProbableExec}_daemon"
        echo $chainProbableDaemon
        daemonPid=$(ps aux | grep "$chainProbableDaemon" | grep -v grep | awk ' { print $2 } ')
        if [ ! -z "$daemonPid" ]; then
                kill $daemonPid
                #Hopefully enough, else loop and wait until gone
                sleep 10s
        fi
        sudo su - "$userOfChain" -c "source $availableChain && $chainProbableExec start farmer"
done
