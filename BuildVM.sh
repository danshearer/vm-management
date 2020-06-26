#!/bin/bash
# 
# Create a new VM by first cloning and then editing the new clone.
#
# Dan Shearer
# June 2020

storageplace="/nvmetank/vms"

PrintHelp() {
	echo " "
	echo "`basename $0`"
	echo " "
	echo "      -t destination VM name. Must be unused, unless -o also specified"
	echo "      -f from VM name, typically a template. VM must be shut down"
	echo "      -o overwrite destination VM config and data"
	echo "      -m MAC address. If supplied, must be valid. If not supplied, will be generated"
	echo " "
	echo "       Hardcoded VM file location is \"$storageplace\""
	echo " "
	exit 1
}

ErrorExit() {
	echo "Error: $1"
	logger -p local2.notice -t VMM "$0 Error exit: $1"
	exit 1
}

DoesVMExist() {
	vname=$1
	# --all also gives VMs that are defined but not running
	tmp=$(virsh list --all | grep $vname | tr -s ' ' | cut -d ' ' -f3)
	if ([ "$vname" == "$tmp" ])
	then
	    return 0
	else
	    return 1
	fi
}

IsVMRunning() {
	# Might need to add tests for how alive the running VM really is
	vname=$1
	tmp=$(virsh list | grep $vname | tr -s ' ' | cut -d ' ' -f3)
	if ([ "$vname" == "$tmp" ])
	then
	    return 0
	else
	    return 1
	fi
}

# Basic MAC checks, or, create random legal MAC. virt-clone also does some validity checks.
MakeMACAddr() {
	MA=$1
	if [[ (-z $MA) ]]; then
		# construct valid private MAC addr in the "E" range. Ranges are listed in the
		# table here: https://en.wikipedia.org/wiki/MAC_address . Use the prefix 
		# CA:FE to make it obvious in ARP tables.
		MA=`printf 'CA:FE:%02X:%02X:%02X\n' $[RANDOM%256] $[RANDOM%256] $[RANDOM%256]`
		echo "Generated random private MAC address in the E private range: $MA"
	else    
		MA=${MA^^}  # capitalise 
		if [[ `echo $MA | egrep "^([0-9A-F]{2}:){5}[0-9A-F]{2}$"` ]]; then
			echo "Valid MAC address supplied: $MA"
		else
			ErrorExit "Invalid MAC address supplied: $MA" ;
		fi
	fi
	# set global variable
	macaddr=$MA
}


while getopts ":t:f:m:odh" flag; do
    case $flag in
        t) tovmname=$OPTARG;;
        f) fromvmname=$OPTARG;;
        o) overwrite="yes";;
	d) debug="yes";;
	m) macaddr=$OPTARG;;
	h) helphelp="help";;
	*) helphelp="help anyway";;
    esac
done

if [[ ! -z $debug ]]; then
   echo "to: $tovmname"
   echo "from: $fromvmname"
   echo "overwrite: $overwrite"
   echo "debug: $debug"
   echo "macaddr: $macaddr"
   echo "helphelp: $helphelp"
fi

if [[ ( $OPTIND -lt 3) || (! -z $helphelp) ]];
then 
	PrintHelp ;
fi

if [[ ( -z $tovmname) || ( -z $fromvmname) ]]; then
	ErrorExit "Needs both -t and -f specified. -h for help" ;
fi

MakeMACAddr $macaddr ;

if (DoesVMExist "$tovmname") then
	if [[ "$overwrite" != "yes" ]]; then
		ErrorExit "VM \"$tovmname\" exists, cannot use as a destination VM name" ; 
	else
		echo " "
		echo "VM \"$tovmname\" exists, type Yes to destroy it and all storage"
		select yn in "Yes" "No"; do
			case $REPLY in
				Yes) virsh undefine $tovmname --remove-all-storage; break;;
				 No) ErrorExit "User selected no-destroy. Better safe than sorry." ;;
			esac
		done
	fi
fi

DoesVMExist "$fromvmname" || { ErrorExit "VM \"$fromvmname\" does not exist, cannot clone it" ; }

IsVMRunning "$fromvmname" && { ErrorExit "VM \"$fromvmname\" is running, shutdown before cloning" ; }


if [[ -f "$storageplace/$tovmname.qcow2" ]];
then
	if [[ $overwrite == "yes" ]];
	then
		echo "Removing dangling storage $storageplace/$tovmname.qcow2"
		rm $storageplace/$tovmname.qcow2
	else
		ErrorExit "$storageplace/$tovmname.qcow2 exists, remove manually." ;
	fi
fi

# Cloning in the following recreates the source disk image without change, including things 
# we don't want such as hostname, any temporary log files, bash history etc. It creates new 
# storage of the right size and correct XML for the new VM. It must be done as root.
# virt-clone can assign a random MAC address in the XML, but we don't ever want this.
echo "==> Starting clone operation"
virt-clone --original $fromvmname --name $tovmname --file $storageplace/$tovmname.qcow2 --mac $macaddr

# This mounts and edits the newly-created clone, removing things we don't want and setting up.
# Running as root although there is no need and it would be safer not to.
# virt-sysprep does a very thorough clean by default but we don't want that at this stage, 
# because eg that includes wiping ssh keys. With --enable we specify only the cleaning we want.
echo "==> Starting sysprep operation"
virt-sysprep --enable net-hostname,dhcp-client-state,bash-history,backup-files,logfiles,utmp -d $tovmname

# virt-customize can be called by virt-sysprep, but not doing so because it feels more in control.
# This is where all the customisation happens, there is no limit because scripts can be called. 
# No need to be running as root.
echo "==> Starting customise operation"
virt-customize --hostname $tovmname -d $tovmname

logger -p local2.info -t VMM "Successful build of VM $tovmname with MAC address $macaddr"

echo " "
echo "==> Successful build of VM $toname with MAC address $macaddr"
