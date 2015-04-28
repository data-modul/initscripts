#!/bin/sh

PATH=/sbin:/bin:/usr/sbin:/usr/bin
ROOTFS='/rootfs'
ROOT_DEV=''
OVERLAY_DEV=''

init_setup() {
	mkdir -p /proc
	mkdir -p /sys
	mkdir -p /dev
	
	echo "Mount proc, sys, dev"
	mount -t proc proc /proc
	mount -t sysfs sysfs /sys
	mount -t devtmpfs none /dev
}

mount_root() {
	mkdir -p $ROOTFS

	if [ -z $OVERLAY_DEV ]; then
		echo "Mount root"
		mount -o ro $ROOT_DEV $ROOTFS		
	else
		echo "Mount overlay, and move"
		mkdir -p /rootfs.ro
		mkdir -p /rootfs.rw
		mount -o ro $ROOT_DEV /rootfs.ro/
		mount $OVERLAY_DEV /rootfs.rw/

		mount -t overlay overlay -olowerdir=/rootfs.ro,upperdir=/rootfs.rw/datadir,workdir=/rootfs.rw/workdir $ROOTFS
		mkdir -p $ROOTFS/rootfs.ro $ROOTFS/rootfs.rw
		mount --move /rootfs.ro $ROOTFS/rootfs.ro
		mount --move /rootfs.rw $ROOTFS/rootfs.rw
	fi

	mount -n --move /proc $ROOTFS/proc
	mount -n --move /sys $ROOTFS/sys
	mount -n --move /dev $ROOTFS/dev
}

parse_cmd() {
	echo "Parse cmd"
	[ -z "$CMDLINE" ] && CMDLINE=`cat /proc/cmdline`
	for arg in $CMDLINE; do
		optarg=`expr "x$arg" : 'x[^=]*=\(.*\)'`
		case $arg in
			debugshell*)
				shell='1' ;;
			root*)
				ROOT_DEV=$optarg ;;
			overlayrw*)
				OVERLAY_DEV=$optarg ;;
		esac
	done
}

init_setup
[ -z "$CONSOLE" ] && CONSOLE="/dev/console"
parse_cmd
echo "ROOT_DEV: $ROOT_DEV"
echo "OVERLAY_DEV: $OVERLAY_DEV"

echo "Check for shell"
if [ ! -n "$shell" ]; then
	echo "Go init"
	mount_root
	cd $ROOTFS
	exec switch_root -c /dev/console $ROOTFS /sbin/init
else
	echo "Execute shell"
	exec sh
fi

