#!/bin/bash

# echo_date ""
# echo_date "Running script: $(realpath $0)"
# echo_date "Script params: $@"
# echo_date ""

#set -eo pipefail

# Define logging function
log_prefix=$(basename $0)
function echo_date {
    echo -e "`date '+%Y-%m-%d %H:%M:%S'`\t${log_prefix}:\t$@"
}

Help() {
    #Display Help
    echo "Mass MikroTik update script."
    echo ""
    echo "Script auto-discovery is based on MikroTik neighbor feature. More info at wiki:"
    echo "https://wiki.mikrotik.com/wiki/Manual:IP/Neighbor_discovery"
    echo ""
    echo "To enable discovery run below command on all MikroTik devices:"
    echo "    /ip neighbor discovery-settings set discover-interface-list=all protocol=cdp,lldp,mndp"
    echo ""
    echo "Authentication is based on RSA keys. Users and keys must be created beforehand"
    echo "https://wiki.mikrotik.com/wiki/Use_SSH_to_execute_commands_(public/private_key_login)"
    echo ""
    echo "Required parameters:"
    echo "    --mikrotik MIKROTIK_IP    It can be any MikroTik in network. Gateway is recomended." 
    echo "    --user     SSH_USER       Admin user used to login via ssh to each MikroTik device."
    echo "    --key      RSA_KEY        RSA key used to login via ssh to each MikroTik device."
    echo ""
    echo "Optional om parameters:"
    echo "    --channel  development|long-term|stable|testing"
    echo "                          Update channel to be used by MikroTik. Default: stable"
    echo "    --reboot   yes|no         Reboot all MikroTik devices AFTER all updates are downloaded. Default:no"
    echo "    --help                    Display this message"
    echo ""
    echo "All parameters must be probided in --key=value format. Example syntax: "
    echo "    $(basename $0) --mikrotik='10.10.10.1' --user='admin-ssh' --key='~/.ssh/mikrotik_2048'"
    echo ""
    
}

# Assigning variables from params
for ARGUMENT in "$@"; do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   
    case $KEY in
        '--mikrotik' )
            MT=${VALUE}
        ;;
        '--user' )
            MT_USER=${VALUE}
        ;;
        '--key' )
            MT_KEY=${VALUE}
        ;;
        '--channel' )
            MT_CHANNEL=${VALUE}
        ;; 
        '--channel' )
            MT_REBOOT=${VALUE}
        ;;                                        
        '--help' )
            Help
            exit 0
        ;;
        * )
            echo_date "[ERROR] Unknown parameter specified!"
            Help
            exit 1
        ;;
    esac
done

if [ -z "$MT" ]; then
    echo_date "[ERROR] [$(basename $0)] '--mikrotik' parameter is mandatory"
    Help
    exit 10
fi

if [ -z "$MT_USER" ]; then
    echo_date "[ERROR] [$(basename $0)] '--user' parameter is mandatory"
    Help
    exit 10
fi

if [ -z "$MT_KEY" ]; then
    echo_date "[ERROR] [$(basename $0)] '--key' parameter is mandatory"
    Help
    exit 10
fi

if [ -z "$MT_CHANNEL" ]; then
    MT_CHANNEL="stable"
    echo_date "[INFO] [$(basename $0)] '--channel' parameter is missing, using $MT_CHANNEL as update channel."
fi

if [ -z "$MT_CHANNEL" ]; then
    MT_CHANNEL="stable"
    echo_date "[INFO] [$(basename $0)] '--channel' parameter is missing, using $MT_CHANNEL as update channel."
fi

echo_date "[INFO] Geting neighbor list from $MT..."
NEIGHBOR=$(ssh -o "StrictHostKeyChecking no" $MT_USER@$MT -i $MT_KEY /ip/neighbor/print | grep -E "([0-9]{1,3}[\.]){3}[0-9]{1,3}")

echo_date "[INFO] ID INTERFACE_NAME        IP_ADDRESS  MAC_ADDRESS        IDENTITY"
while IFS= read -r line; do
    echo_date "[INFO] $line"; 
done <<< "$NEIGHBOR"

echo_date "[INFO] Running auto-update on all detected MikroTik devices..."
MT_LIST="$MT $(echo $NEIGHBOR | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}")"
MT_LIST=($(for MT in $MT_LIST; do echo $MT; done | sort -r))

for MT in ${MT_LIST[@]}; do
    echo_date "[$MT] Setting $MT_CHANNEL as main update channel ..."
    ssh -o "StrictHostKeyChecking no" $MT_USER@$MT -i $MT_KEY "/system/package/update/set channel=$MT_CHANNEL"

    echo_date "[$MT] Checking for updates ..."
    MT_UPDATE_STATUS=$(ssh -o "StrictHostKeyChecking no" $MT_USER@$MT -i $MT_KEY "/system/package/update/check-for-updates" | grep status | tail -n1)
    if [[ $(echo $MT_UPDATE_STATUS | grep "up to date") ]]; then 
        echo_date "[$MT]$(echo $MT_UPDATE_STATUS | cut -d':' -f2)!"
        echo_date "[$MT] Skipping!"
    else
        echo_date "[$MT]$(echo $MT_UPDATE_STATUS | cut -d':' -f2)!"
        echo_date "[$MT] Downloading update..."
        MT_DOWNLOAD_STATUS=$(ssh -o "StrictHostKeyChecking no" $MT_USER@$MT -i $MT_KEY "/system/package/update/download" | grep status | tail -n1)
        echo_date "[$MT]$(echo $MT_DOWNLOAD_STATUS | cut -d':' -f2)!"
    fi
done

echo_date "Rebooting all MikroTik devices..."
for MT in ${MT_LIST[@]}; do
    echo_date "[$MT] Rebooting..."
    (ssh -o "StrictHostKeyChecking no" $MT_USER@$MT -i $MT_KEY ":execute {/system reboot}") &
done

echo_date ""
echo_date "Done!"
