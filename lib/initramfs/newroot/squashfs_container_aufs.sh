# ----------------------------------------------------------------------------
#
# This module extends squashfs_container by memory-writable squashfs mounts,
# which requires Aufs support (preferably Aufs3) in the kernel.
#
# It adds 2 functions:
#
# int sfs_container_mount_writable()         -- sfs_name, mp, size, aufs_root
# int newroot_sfs_container_mount_writable() -- sfs_name, mp, [size=100]
#
# These functions are assumed to be provided by the squashfs_container module:
#
# @extern void newroot_sfs_container_init()  -- mp, size_m; raises initramfs_die()
# @extern int  newroot_sfs_container_mount() -- name, mp
# @extern int  sfs_container_avail()
# @extern int  sfs_container_downsize()
# @extern int  sfs_container_finalize()
# @extern int  sfs_container_import()        -- sfs_file, sfs_name
# @extern void sfs_container_init()          -- mp, size_m; raises initramfs_die()
# @extern int  sfs_container_lock()
# @extern int  sfs_container_mount()         -- name, mp
# @extern int  sfs_container_unlock()
#
# ----------------------------------------------------------------------------

## @extern @private int aufs_tmpfs_backed (
##    aufs_mp, tmpfs_mp, tmpfs_size[_m],
##    rr_branches, ro_branches, aufs_name, aufs_opts
## )
##
##  Just a reminder.
##

# int sfs_container_mount_writable (
#    sfs_name, mp, size[_m], aufs_root,
#    **SFS_CONTAINER_NAME
# )
#
#  Mounts a writable variant of sfs_name at mp.
#
#  Actually mounts an aufs<rw=tmpfs,rr=squashfs>, after mounting the
#  squashfs file and the tmpfs under %aufs_root/%SFS_CONTAINER_NAME/.
#
sfs_container_mount_writable() {
   : ${1:?} ${2:?} ${3:?} ${4:?}

   local \
      sfs_mp="${4:?}/${SFS_CONTAINER_NAME}/persistent/${1:?}" \
      tmpfs_mp="${4:?}/${SFS_CONTAINER_NAME}/volatile/${1:?}"

   inonfatal sfs_container_mount "${1}" "${sfs_mp}" && \
   inonfatal aufs_tmpfs_backed \
      "${2}" "${tmpfs_mp}" "${3}" "${sfs_mp}" "" "${1}"
}

# int newroot_sfs_container_mount_writable (
#    sfs_name, mp, size[_m]:=100, **SFS_CONTAINER_NAME
# )
#
#  newroot-specific version of sfs_container_mount_writable().
#
#  Uses an hardcoded aufs_root path and sets size to 100 unless specfied.
#
newroot_sfs_container_mount_writable() {
   local v0
   newroot_doprefix "${2:?}"
   sfs_container_mount_writable \
      "${1:?}" "${v0:?}" "${3:-100}" "${NEWROOT}/aufs_root"
}

# @function_alias sfs_container_mount_writeable()
#  renames sfs_container_mount_writable()
sfs_container_mount_writeable() { sfs_container_mount_writable "$@"; }

# @function_alias newroot_sfs_container_mount_writeable()
#  renames newroot_sfs_container_mount_writable()
newroot_sfs_container_mount_writeable() {
   newroot_sfs_container_mount_writable "$@"
}
