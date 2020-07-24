# Virtual Machine Tools

This addresses the problem of what to do if you have a few handfuls of virtual machines 
to run on your own hardware including laptops, and you're not interested in orchestration 
tools because they are too complicated for the task. 

Modern [libvirt](https://gitlab.com/libvirt) does nearly everything required, and it doesn't 
tend to keep changing underneath us, so all that is needed is some scripting around virsh and 
the virt-* tools. 

Features include:

* IP management by MAC address
* supply a network or bridge (which, strangely, required editing the XML for the new VM)
* a simple way to customise a template VM, eg to recreate a standard firewall VM say

Here is the help output:

````
BuildVM.sh
 
   mandatory options:
      -t destination VM name. Must be unused, unless -o also specified
      -f from VM name, typically a template. VM must be shut down
 
   optional options:
      -o overwrite destination VM config and data
      -y together with -o, quietly overwrite with yes to all questions. DANGEROUS!
      -m MAC address. If supplied, must be valid. If not supplied, will be generated
      -4 IPv4 address. If -m supplied, -4 is mandatory
      -r RAM size, in M (mebibytes). Number only, do not specify units
      -b bridge network to attach to. Must appear in output of virsh net-list
      -c filename in which virt-customize commands are kept
      -d debug
 
       Hardcoded VM file location is "/var/lib/libvirt/images"
 
       Must be run as root for now
 ````
