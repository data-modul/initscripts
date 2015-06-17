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

falltoshell() {
        echo Fall to shell!
	exec sh
}

createExt3() {
	echo !The $OVERLAY_DEV partition will be recreated!
	mkfs.ext3 -F $OVERLAY_DEV
	exit 0
}


mount_root() {
	declare -i result=-1
	mkdir -p $ROOTFS

	if [ -z $OVERLAY_DEV ]; then
		echo "Mount only root"
		mount -o ro $ROOT_DEV $ROOTFS		
	else
		echo "Mount overlay and root"
		mkdir -p /rootfs.ro
		mkdir -p /rootfs.rw
		mount -o ro $ROOT_DEV /rootfs.ro/
		result=$?
		if [ 0 != $result ]; then
			echo Error mounting root partition
			falltoshell
		fi

		result=-1
		mount $OVERLAY_DEV /rootfs.rw/
		result=$?
		if [ 0 != $result ]; then
			echo Run e2fsck on $OVERLAY_DEV
			result=-1
			e2fsck $OVERLAY_DEV -y
			result=$?
			if [ 3 -gt $result ]; then
				echo Second try mounting $OVERLAY_DEV
				result=-1
				mount $OVERLAY_DEV /rootfs.rw/
				result=$?
				if [ 0 != $result ]; then
					echo Error mounting overlayfs
					falltoshell
				fi
			else
				echo Error during e2fsck on $OVERLAY_DEV
				falltoshell
			fi
		fi

		[ ! -d /rootfs.rw/datadir ] && mkdir /rootfs.rw/datadir
		[ ! -d /rootfs.rw/workdir ] && 	mkdir /rootfs.rw/workdir

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
			root=*)
				ROOT_DEV=$optarg ;;
			overlayrw=*)
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

