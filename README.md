# Virtual Machine Tools

This addresses the problem of managing a few handfuls of virtual machines to
run on your own hardware including laptops, and you're not interested in
orchestration tools because they are too complicated for the task. 

Modern [libvirt](https://gitlab.com/libvirt) does nearly everything required, and it doesn't 
tend to keep changing underneath us, so all that is needed is some scripting around virsh and 
the virt-* tools. 

Features include:

* IP management by MAC address, and optionally DHCP static requests
* supply a network or bridge (which, strangely, required editing the XML for the new VM)
* a simple way to customise a template VM, eg to recreate a standard firewall VM or DNS VM
* logging VM build process via syslog

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
      -b bridge network to attach to. Must appear in output of virsh net-list
      -r RAM size, in M (mebibytes). Number only, do not specify units
      -c filename in which virt-customize commands are kept, eg /files/dns-server.txt
      -d debug
 
       Hardcoded VM file location is "/dev/null". You may want to change this.
 
       Must be run as root
 
       examples: 
 
              ./BuildVM.sh -t MyNewServer -f DebianTemplate -r 2048
 
              ./BuildVM.sh -t AnotherVM -f TemplateVM -r 256 -m aa:fe:aa:aa:aa:01 -4 81.187.159.24
 
        (-m can come from a locally-administered mac address range, see 'Mac Address' in Wikipedia)
 
````
