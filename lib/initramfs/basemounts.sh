: ${PROC_OPTS:=rw,nosuid,nodev,noexec,relatime}
: ${SYSFS_OPTS:=rw,nosuid,nodev,noexec,relatime}

# void basemounts_mount ( **DEVFS_TYPE=devtmpfs, **PROCFS_OPTS, **SYSFS_OPTS )
#
#  Creates a minimal static /dev and mounts all basemounts afterwards,
#  namely /proc, /sys, /dev and /dev/pts (in that order).
#
basemounts_mount() {
   devfs_seed
   irun dodir_clean /proc /sys
   imount -t proc  -o ${PROCFS_OPTS:?} proc  /proc
   imount -t sysfs -o ${SYSFS_OPTS:?}  sysfs /sys
   devfs_mount
}

# @private void basemounts__default_umount()
#
#  Common code for basemounts_move_newroot() and basemounts_umount().
#  Unmounts /dev/pts, /dev/shm and any directory in /mnt/.
#
basemounts__default_umount() {
   if [ -d /mnt ]; then
      local d
      for d in /mnt/?*; do
         if [ -d "${d}" ]; then
            irun unmount_if_mounted "${d}"
         fi
      done
   fi

   if [ "x${DEVFS_TYPE-}" != "xmdev" ]; then
      irun dofile /proc/sys/kernel/hotplug "" "n"
   fi
   irun unmount_if_mounted /dev/pts
   irun unmount_if_mounted /dev/shm

   return 0
}

# void basemounts_move_newroot ( **NEWROOT, **INITRAMFS_MOVE... )
#
#  Moves the basemounts to newroot (or unmounts them, depending on the
#  INITRAMFS_MOVE_<basemount> variables).
#  Useful if you want to keep volume groups, raid arrays etc.
#
#  Call this function just before switching to newroot.
#
basemounts_move_newroot() {
   : ${NEWROOT:?}

   basemounts__default_umount

   if [ "${INITRAMFS_MOVE_DEV:-y}" = "y" ]; then
      imount --move /dev  "${NEWROOT}/dev"
   else
      iumount /dev
   fi

   if [ "${INITRAMFS_MOVE_SYS:-y}" = "y" ]; then
      imount --move /sys  "${NEWROOT}/sys"
   else
      iumount /sys
   fi

   if [ "${INITRAMFS_MOVE_PROC:-y}" = "y" ]; then
      imount --move /proc "${NEWROOT}/proc"
   else
      iumount /proc
   fi
}

# void basemounts_umount()
#
#  Unmounts all basemounts.
#
basemounts_umount() {
   basemounts__default_umount

   iumount /dev
   iumount /sys
   iumount /proc
}

# @function_alias basemounts_unmount() renames basemounts_umount()
basemounts_unmount() { basemounts_umount "$@"; }

# void initramfs_baselayout ( **NEWROOT! )
#
#  The initramfs base layout.
#
#  Creates essential (and non-essential) directories and initializes
#  the basemounts /proc, /sys, /dev and /dev/pts.
#
#  Sets NEWROOT to /newroot if unset.
#
initramfs_baselayout() {
   irun busybox_overlay /busybox
   irun dodir_clean /bin /sbin "${NEWROOT:=/newroot}"
   inonfatal dodir_clean /etc /var/log /var/run /run /mnt
   basemounts_mount
}

# void basemounts_stop ( **NEWROOT, **INITRAMFS_MOVE_BASEMOUNTS=y )
#
#  Calls basemounts_move_newroot() if INITRAMFS_MOVE_BASEMOUNTS is set to 'y',
#  else calls basemounts_umount().
#
basemounts_stop() {
   if [ "${INITRAMFS_MOVE_BASEMOUNTS:-y}" = "y" ]; then
      basemounts_move_newroot
   else
      basemounts_umount
   fi
}
