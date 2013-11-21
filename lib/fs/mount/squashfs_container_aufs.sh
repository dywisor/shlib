#@section header
# ----------------------------------------------------------------------------
#
# This module extends squashfs_container by memory-writable squashfs mounts,
# which requires Aufs support (preferably Aufs3) in the kernel.
#
# It adds 2 functions:
#
# int sfs_container_mount_writable_rooted() -- sfs_name, mp, size, aufs_root
# int sfs_container_mount_writable_clean()  -- sfs_name, mp, size, sfs_mp, tmpfs_mp
#
# These functions are assumed to be provided by the squashfs_container module:
#
# @extern int  sfs_container_avail()
# @extern int  sfs_container_downsize()
# @extern int  sfs_container_finalize()
# @extern int  sfs_container_import()        -- sfs_file, sfs_name
# @extern int  sfs_container_remove()        -- sfs_name
# @extern void sfs_container_init()          -- mp, size_m
# @extern int  sfs_container_lock()
# @extern int  sfs_container_mount()         -- sfs_name, mp
# @extern int  sfs_container_unlock()
#
# ----------------------------------------------------------------------------

#@section functions

## @extern @private int aufs_tmpfs_backed (
##    aufs_mp, tmpfs_mp, tmpfs_size[_m],
##    rr_branches, ro_branches, aufs_name, aufs_opts
## )
##
##  Just a reminder.
##

# int sfs_container_mount_writable_rooted (
#    sfs_name, mp, size[_m], aufs_root, aufs_opts=
#    **SFS_CONTAINER_NAME
# )
#
#  Mounts a writable variant of sfs_name at mp.
#
#  Actually mounts an aufs<rw=tmpfs,rr=squashfs>, after mounting the
#  squashfs file and the tmpfs under %aufs_root/%SFS_CONTAINER_NAME/.
#
sfs_container_mount_writable_rooted() {
   sfs_container_mount_writable_clean \
      "${1}" "${2}" "${3}" \
      "${4:?}/${SFS_CONTAINER_NAME}/persistent/${1:?}" \
      "${4:?}/${SFS_CONTAINER_NAME}/volatile/${1:?}" \
      "${5-}"
}

# @function_alias sfs_container_mount_writable()
#  renames sfs_container_mount_writable_rooted()
#
sfs_container_mount_writable() { sfs_container_mount_writable_rooted "$@"; }

# int sfs_container_mount_writable_clean (
#    sfs_name, mp, size[_m], sfs_mp, tmpfs_mp, aufs_opts=
# )
#
#  Like sfs_container_mount_writable_rooted(),
#  but allows user-specified mountpoints of the tmpfs and the squashfs file.
#
sfs_container_mount_writable_clean() {
   : ${1:?} ${2:?} ${3:?} ${4:?} ${5:?}

   sfs_container_mount "${1}" "${4}" && \
   aufs_tmpfs_backed "${2}" "${5}" "${3}" "${4}" "" "${1}" "${6-}"
}
