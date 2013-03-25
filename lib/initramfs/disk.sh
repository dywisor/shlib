# void __devfs_resolve_disk_do_scan (...)
#
#  Helper function for devfs_resolve_disk(). "Updates" /dev.
#
__devfs_resolve_disk_do_scan() {
   # the order is important here,
   #  mdadm arrays may be volume groups, but it's not expected that volume
   #  groups are part of an mdadm array
   #
   ! initramfs_use mdadm           || irun devfs_mdadm
   ! initramfs_use lvm             || irun devfs_lvm
   [ "${DEVFS_TYPE:?}" != "mdev" ] || irun mdev -s
}

# int initramfs_waitfor_disk (...)
#
#  Initramfs variant of waitfor_disk() from fs/disk.
#
initramfs_waitfor_disk() {
   local F_WAITFOR_DISK_DEV_SCAN=__devfs_resolve_disk_do_scan
   waitfor_disk "$@"
}

# int initramfs_mount_disk_nonfatal (
#    mp, disk_identifier, opts=<auto>, fstype=<auto>, fsck=y
# )
#
#  Tries to find the device identified by disk_identifier and mounts
#  it. Optionally performs a filesystem check just before mounting.
#
#  !!! only ext2/3/4 file systems will be fscked,
#      other filesystems are assumed to be clean
#
initramfs_mount_disk_nonfatal() {
   local DISK_DEV
   if initramfs_waitfor_disk "${2:?}"; then
      if [ "${5:-y}" = "y" ]; then
         case "${4-}" in
            ext?)
               do_fsck || return
            ;;
            # xfs, btrfs, ...?
         esac
      fi
      domount_fs "${1:?}" "${DISK_DEV:?}" "${3-}" "${4-}"
   else
      return 20
   fi
}

# void initramfs_mount_disk (...)
#
#  Calls initramfs_mount_disk_nonfatal(...) and dies on non-zero return.
#
initramfs_mount_disk() {
   irun initramfs_mount_disk_nonfatal "$@"
}

# @function_alias imount_disk() copies initramfs_mount_disk()
imount_disk() { irun initramfs_mount_disk_nonfatal "$@"; }
