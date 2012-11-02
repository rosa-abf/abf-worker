#!/bin/sh

ch="$PRODUCTNAME"
echo $PRODUCTNAME
echo $REPO
echo $externalarch
echo $lst
mkdir $ch
umount $ch/sys
umount $ch/proc
umount $ch/dev/pts
umount $ch/iso
umount $ch/dev
urpmi.addmedia --urpmi-root $PRODUCTNAME --distrib $REPO
urpmi --urpmi-root $PRODUCTNAME --root $PRODUCTNAME basesystem-minimal basesystem urpmi rpm locales-en locales-ru rpm-build livecd-tools syslinux livecd-iso-to-disk --auto
mkdir -p $ch/dev
mkdir -p $ch/dev/pts
mkdir -p $ch/proc
mkdir -p $ch/sys
mkdir -p $ch/opt

mount --bind /dev/     $ch/dev
mount --bind /dev/pts   $ch/dev/pts
mount --bind /proc      $ch/proc
mount --bind /sys       $ch/sys
cp /etc/resolv.conf $ch/etc/

cd $ch/opt/
git clone $SRCPATH ISOBUILD
cd ISOBUILD
git checkout $branch
for x in $externalarch; do
echo $x
cp $x$lst.lst $x.lst
done
cd ../../../


echo 
echo "----------> UR IN Z MATRIX <----------"


PRODUCTNAME=$PRODUCTNAME externalarch=$externalarch /usr/sbin/chroot $ch /opt/ISOBUILD/build 2>&1 > build.log
umount -l $ch/sys
umount -l $ch/proc
umount -l $ch/dev/pts
umount -l $ch/iso
umount -l $ch/dev
