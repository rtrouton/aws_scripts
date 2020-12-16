This AWS userdata script is designed to configure an AWS Mac EC2 instance on first boot with the following:

* git
* AutoPkg
* AutoPkgr
* JSSImporter

The following optional settings can also be set:

* Account password for the default `ec2-user` account
* Enabling VNC
* Enabling auto-login for the default `ec2-user` account


Once these tools and modules are installed, the script configures AutoPkg to use the recipe repos defined in the AutoPkg repos section.