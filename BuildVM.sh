#!/bin/bash
#
# Create Virtual Machines Without Complication
#
# For a few dozens of VMs orchestration tools get far too complicated, especially if many of
# them are on a laptop or for development/testing. Modern libvirt does nearly everything required, so all 
# that is needed is to script virsh and the virt-* tools. One of the main requirements is IP management,
# and another is having a simple way to customise a template VM.
#
# Uses virsh, virt-clone, virt-sysprep and virt-customize.
#
# Dan Shearer
# June 2020

storageplace="/var/lib/libvirt/images/"

PrintHelp() {
	echo " "
	echo "`basename $0`"
	echo " "
	echo "   mandatory options:"
	echo "      -t destination VM name. Must be unused, unless -o also specified"
	echo "      -f from VM name, typically a template. VM must be shut down"
	echo " "
	echo "   optional options:"
	echo "      -o overwrite destination VM config and data"
	echo "      -q together with -o, quietly overwrite with no questions. DANGEROUS!"
	echo "      -m MAC address. If supplied, must be valid. If not supplied, will be generated"
	echo "      -4 IPv4 address. If -m supplied, -4 is mandatory"
	echo "      -c filename in which virt-customize commands are kept"
	echo "      -d debug"
	echo " "
	echo "       Hardcoded VM file location is \"$storageplace\""
	echo " "
	echo "       Must be run as root"
	echo " "
	exit 1
}

ErrorExit() {
	echo "`basename $0`"
	echo "        Error: $1"
	echo "-h for help"
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
	if [[ -z $MA ]]; then
		# construct valid private MAC addr in the "E" range. Ranges are listed in the
		# table here: https://en.wikipedia.org/wiki/MAC_address . Use the prefix 
		# CA:FE to make it obvious in ARP tables.
		MA=`printf 'CA:FE:%02X:%02X:%02X:%02X\n' $[RANDOM%256] $[RANDOM%256] $[RANDOM%256] $[RANDOM%256]`
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

while getopts ":t:f:m:4:c:oqdh" flag; do
    case $flag in
        t) tovmname=$OPTARG;;
        f) fromvmname=$OPTARG;;
        o) overwrite="yes";;
	q) quietoverwrite="yes";;
	d) debug="yes";;
	m) macaddr=$OPTARG;;
	4) ipaddr=$OPTARG;;
	c) commandfile=$OPTARG;;
	h) helphelp="help";;
	\?) ErrorExit "Unknown option -$OPTARG" ;;
        :) ErrorExit "Missing option argument for -$OPTARG" ;;
        *) ErrorExit "Unimplemented option: -$OPTARG" ;;
    esac
done

if [[ $debug == "yes" ]]; then
   echo "to: $tovmname"
   echo "from: $fromvmname"
   echo "overwrite: $overwrite"
   echo "quietoverwrite: $quietoverwrite"
   echo "debug: $debug"
   echo "macaddr: $macaddr"
   echo "ipaddr: $ipaddr"
   echo "commandfile: $commandfile"
   echo "helphelp: $helphelp"
fi

if [[ ( $OPTIND -lt 3) || (! -z $helphelp) ]];
then 
	PrintHelp ;
fi

if [[ ( -z $tovmname) || ( -z $fromvmname) ]]; then
	ErrorExit "Needs both -t and -f specified" ;
fi

if [[ ( ! -z $quietoverwrite ) && ( -z $overwrite) ]]; then
	ErrorExit "No -q quiet overwrite without -o overwrite" ;
fi

if [[ ( ! -z $commandfile ) && ( ! -f $commandfile) ]]; then
	ErrorExit "specified commandfile \"$commandfile\" does not exist" ;
fi

if [[ ($EUID -ne 0) ]]; then
	ErrorExit "Script not running as root. Not ideal, but needed for now" ;
fi

if [[ ! -z $macaddr ]]; then
	if [[ -z $ipaddr ]]; then
		ErrorExit "If you specify -m you must also specify -4" ;
	fi
fi

MakeMACAddr $macaddr ;

if (DoesVMExist "$tovmname") then
	if [[ "$overwrite" != "yes" ]]; then
		ErrorExit "VM \"$tovmname\" exists, cannot use as a destination VM name" ; 
	else
		if [[ "$quietoverwrite" != "yes" ]]; then
			echo " "
			echo "VM \"$tovmname\" exists, type Yes to destroy it and all storage"
			select yn in "Yes" "No"; do
				case $REPLY in
					Yes) break;;
				 	No) ErrorExit "User selected no-destroy. Better safe than sorry." ;;
				esac
			done
		fi
		if ( ! virsh undefine $tovmname --remove-all-storage) then
			ErrorExit "virsh undefine failed, is domain running?" 
		fi	
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
# virt-clone can assign what it calls a random MAC address in the XML, being a QEMU
# range with the last three bytes randomised. We don't ever want this (see 
# https://en.wikipedia.org/wiki/MAC_address#Universal_Addresses_that_are_Administered_Locally )
echo "==> Starting clone operation"
virtcommand="virt-clone --original $fromvmname --name $tovmname --file $storageplace/$tovmname.qcow2 --mac=$macaddr"
if [[ ! -z $debug ]]; then echo "about to run: $virtcommand" ; fi
eval $virtcommand
if [[ ( $? != 0 ) ]]; then ErrorExit "Failed: $virtcommand" ; fi


# This mounts and edits the newly-created clone, removing things we don't want and setting up.
# Running as root although there is no need and it would be safer not to.
# virt-sysprep does a very thorough clean by default but we don't want that at this stage, 
# because eg that includes wiping ssh keys. With --enable we specify only the cleaning we want.
echo "==> Starting sysprep operation"
virtcommand="virt-sysprep --enable net-hostname,dhcp-client-state,bash-history,backup-files,logfiles,utmp -d $tovmname"
if [[ ! -z $debug ]]; then echo "about to run: $virtcommand" ; fi
eval $virtcommand
if [[ ( $? != 0 ) ]]; then ErrorExit "Failed: $virtcommand" ; fi

# virt-customize can be called by virt-sysprep, but not doing so because it feels more in control.
# This is where all the customisation happens, there is no limit because scripts can be called. 
# No need to be running as root.
echo "==> Starting customise operation"
virtcommand="virt-customize --hostname $tovmname -d $tovmname"
if [[ ! -z $commandfile ]]; then virtcommand="$virtcommand -c $commandfile" ; fi
if [[ ! -z $debug ]]; then echo "about to run: $virtcommand" ; fi
eval $virtcommand
if [[ ( $? != 0 ) ]]; then ErrorExit "Failed: $virtcommand" ; fi


logger -p local2.info -t VMM "Successful build of VM $tovmname with MAC address $macaddr"

echo " "
echo "==> Successful build of VM $toname with MAC address $macaddr"
