# Virtual Machine Tools

Tools for virtual machines where you have a few physical machines and at most a few dozens of 
virtual machines. Orchestration tools get far too complicated, especially if many of
the VMs are for development/testing or maybe on a laptop. Modern libvirt does nearly everything required, so all 
that is needed is to script virsh and the virt-* tools. One of the main requirements is IP management by MAC address,
and another is having a simple way to customise a template VM.
