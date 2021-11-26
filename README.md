# Create Handfuls of Virtual Machines With libvirt

TL;DR: Create VMs from templates using libvirt's commandline tools and nothing else.

Hope you find it useful.

--
Dan Shearer
dan@shearer.org

# More Details

This script is for managing small handfuls of virtual machines to
run on your own hardware including laptops. You might like it if 
orchestration tools are too complicated for your small task.

Modern [libvirt](https://gitlab.com/libvirt) comes with nearly everything
required if you are looking for management rather than orchestration. Something
Libvirt doesn't do so well is help you create images in the first place. That's
what this script does.

[Kubernetes](https://kubernetes.io), [Kontena](https://www.kontena.io/) and
similar software are very large, and people can have jobs and careers in them.
On the other hand,
[Virt-Manager](https://virt-manager.org/) is a manual GUI application. This
script is a simple, partly-automated commandline solution.

You'll need to do your own monitoring, but you'll be expecting that.

Features of this script include:

* IP management by MAC address, and optionally DHCP static requests
* supply a network or bridge (which, strangely, requires editing the XML for the new VM)
* a simple way to customise a template VM, eg to recreate a standard firewall VM or DNS VM
* logging VM build process via syslog

Many potential race conditions exist, so only run one copy at once.

This is a bash script, not a Bourne shell script.

Here is the help output, prior to setting a VM image destination:

````
BuildVM.sh version 1.0
 
   !!SET VM DESTINATION!! Assign $storageplace at the top of /home/dan/d/vm-management/BuildVM.sh.
 
   mandatory options:
      -t destination VM name. Must be unused, unless -o also specified
      -f from VM name, typically a template. VM must not be currently running
 
   optional options:
      -o overwrite destination VM config and data. Will ask an interactive question
      -y together with -o, quietly overwrite with yes to all questions. DANGEROUS!
      -m MAC address. If supplied, must be valid. If not supplied, will be generated
      -4 IPv4 address. If -m supplied, -4 is mandatory
      -b bridge network to attach to. Must appear in output of virsh net-list
      -r RAM size, in M (mebibytes). Number only, do not specify units
      -c filename in which virt-customize commands are kept, eg /files/dns-server.txt
      -s start the VM after creating it
      -d debug. Write status information to console.
 
       Successful builds and starts, and fatal errors, are sent to syslog facility local2.info
 
 
       Must be run as root. This script is not secure and could destroy your system.
       This is a bash script, not a bourne or other shell script.
 
       examples: 
 
              ./BuildVM.sh -t MyNewServer -f DebianTemplate -r 2048
 
              ./BuildVM.sh -t AnotherVM -f TemplateVM -r 256 -m aa:fe:aa:aa:aa:01 -4 10.17.91.8
 
        (-m can come from a locally-administered mac address range, see 'Mac Address' in Wikipedia)
 
````
