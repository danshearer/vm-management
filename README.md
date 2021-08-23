# Create Handfuls of Virtual Machines With libvirt

TL;DR: Create VMs from templates using libvirt's tools and nothing else

This addresses the problem of managing a few handfuls of virtual machines to
run on your own hardware including laptops, and you're not interested in
orchestration tools because they are too complicated for the task.
[Kubernetes](https://kubernetes.io), [Kontena](https://www.kontena.io/) and
various other stackings-up of containers, orchestration and so on are the sort
of thing people get a career in. On the other hand,
[Virt-Manager](https://virt-manager.org/) is very manual.

Modern [libvirt](https://gitlab.com/libvirt) comes with nearly everything
required if you are looking for management rather than orchestration. Libvirt
doesn't tend to keep changing underneath us, so all that is needed is some
scripting around the commandline virsh and the virt-* tools. You'll need to do your own
monitoring, but you'll be expecting that and it is not difficult anyway.

Something Libvirt doesn't do so well is help you create images in the first
place. That's what this script does.

Features of this script include:

* IP management by MAC address, and optionally DHCP static requests
* supply a network or bridge (which, strangely, requires editing the XML for the new VM)
* a simple way to customise a template VM, eg to recreate a standard firewall VM or DNS VM
* logging VM build process via syslog

This is a bash script, not a Bourne shell script.

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
      -s start the VM after creating it
      -d debug
 
       Hardcoded VM file location is "/dev/zero". You may want to change this.
 
       Must be run as root
 
       examples: 
 
              ./BuildVM.sh -t MyNewServer -f DebianTemplate -r 2048
 
              ./BuildVM.sh -t AnotherVM -f TemplateVM -r 256 -m aa:fe:aa:aa:aa:01 -4 10.17.91.8
 
        (-m can come from a locally-administered mac address range, see 'Mac Address' in Wikipedia)
 
````
