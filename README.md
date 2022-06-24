# Mass MikroTik update script.

## Requirements 
Script auto-discovery is based on MikroTik neighbor feature. More info at wiki:
<https://wiki.mikrotik.com/wiki/Manual:IP/Neighbor_discovery>

To enable discovery run below command on all MikroTik devices:
```MikroTik
/ip neighbor discovery-settings set discover-interface-list=all protocol=cdp,lldp,mndp
```

Authentication is based on RSA keys. Users and keys must be created beforehand:
<https://wiki.mikrotik.com/wiki/Use_SSH_to_execute_commands_(public/private_key_login)>

## Help

### Required parameters:
```Bash
    --mikrotik MIKROTIK_IP    It can be any MikroTik in network. Gateway is recomended. 
    --user     SSH_USER       Admin user used to login via ssh to each MikroTik device.
    --key      RSA_KEY        RSA key used to login via ssh to each MikroTik device.
```

### Optional parameters:
```Bash
    --channel  development|long-term|stable|testing
                            Update channel to be used by MikroTik. Default: stable
    --reboot   yes|no         Reboot all MikroTik devices AFTER all updates are downloaded. Default:no
    --help                    Display this message
```

## Example 
```Bash
./mikrotik_update.sh --mikrotik='10.10.10.1' --user='admin-ssh' --key='~/.ssh/mikrotik_2048' --channel='stable' --reboot='yes'
```
    
