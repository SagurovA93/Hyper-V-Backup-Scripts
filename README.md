# Hyper-V Backup Script 

Export Virtual Machine from Hyper-V<br>
Simple automated backup script for virtual machines from Hyper-V<br>
Script allows you to export virtual machine without shutting down virtual machine

## Requirements (some notes about running this script)

* Script must run on Hyper-V host from which you're going to export Virtual Machines
* If you want export VM into network folder on another host you need to grant write privileges on that network directory to Hyper-V host
* Be aware about retention period (number of copies) from configuration file. If it equals to zero - you won't get any backup

## Configuration file

In configuration file you need to fill the following columns:
* VM name          - Virtual Machine name. It allowed to be different from real virtual machine name 
* VM id            - Virtual Machine ID. You may get it using command: Get-VM -Name VirtualMachine_Name | Select-Object Id
* month   	   - Available values: from 1 (January) up to 12 (December), if you doesn't need to specify every month, just use "*" - it will means all months
* day     	   - Available values: mon,tue,wed,thu,fri,sat,sun. If you want everyday backup - use "*" it will means everyday
* number of copies - Number of copies which must be kept forVirtual Machines. For example, if this parameter equals 2, and 2 backups already done, after making 3rd copy, the oldest one will be removed from backup directory automatically. This is some kind of "retention period"
* backup dir       - Directory where to export Virtual Machine. It can be a samba shared directory on another host and local directory

### Getting Virtual Machine ID
Get-VM -Name VirtualMachine_Name | Select-Object Id<br>
Then add this ID into config file
