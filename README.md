abf-worker
==========

abf-worker


for run:
VAGRANT_LOG=INFO RESQUE_TERM_TIMEOUT=10000 TERM_CHILD=1 VVERBOSE=1 QUEUE=iso_worker bundle exec rake resque:work

Destroy VM's:
rake abf_worker:clean_up

MDV install:
for install you should press to "tab" and append " serverinstall"
echo BOOTPROTO=dhcp >>/etc/sysconfig/network/scripts/ifcfg-eth0
can be cleaned:
ONBOOT=yes
NM_CONTROLLED=yes

echo nameserver 8.8.8.8 >> /etc/resolvconf/resolv.conf.d/head
reboot

urpmi.addmedia --distrib http://abf.rosalinux.ru/downloads/rosa2012.1/repository/x86_64


Building BOX:
- create user "useradd vagrant"
- set password "passwd vagrant"
- usermod -a -G mock(-urpm) vagrant # Add user into the group

Creating BOX:
packages:
- openssh-client
- openssh-server
- git
- VBoxGuestAdditions_4.2.4

VBoxGuestAdditions_4.2.4:
- mount VBoxGuestAdditions_4.2.4.iso to VB
- mkdir /media/cdrom0
- mount -t iso9660 /dev/hdc /media/cdrom0/
- cd /media/cdrom0/
- urpmi kernel-nrj-desktop-devel-latest # for mdv
- ./VBoxLinuxAdditions.run
- cd ~
- umout /dev/hdc
- rm -rf /media/cdrom0/


Fix "sudo: must be setuid root":
- echo "vagrant ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
- chmod 4755 /usr/bin/su*

Fix "sorry, you must have a tty to run sudo":
- Открываем файл sudoers, находим в нем строчку:Default requiretty
- закомментируем ее

Edit /etc/ssh/sshd_conf file:
- PermitRootLogin no

.ssh folder:
chown vagrant:vagrant -R /home/vagrant/.ssh
curl -L -O https://raw.github.com/avokhmin/vagrant/master/keys/vagrant.pub
chmod 700 /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/authorized_keys
chkconfig add sshd # for mdv

Export VM from VirtualBox to *.box file (Example):
bundle exec vagrant package --base 'rosa64' --output 'rosa.x86_64'
bundle exec vagrant box add 'ROSA.2012.LTS.x86_64' ~/workspace/warpc/rosa.x64_86

Packages:

- sudo urpmi git-core --auto
- sudo urpmi python-lxml --auto
- sudo urpmi python-rpm --auto
- sudo urpmi mock-urpm --auto # mdv
- sudo urpmi mock --auto # rhel
- sudo urpmi rpm-build --auto
- sudo urpmi python-gitpython --auto
- sudo urpmi ruby --auto