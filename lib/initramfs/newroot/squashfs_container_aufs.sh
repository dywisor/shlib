#@section header
# quickref
#
# int newroot_sfs_container_mount_writable() -- sfs_name, mp, size, aufs_root
#
# @extern int newroot_sfs_container_mount()     -- sfs_name, mp
# @extern void newroot_sfs_container_init()     -- mp, size_m
# @extern int newroot_sfs_container_import()    -- sfs_file, sfs_name
# @extern int newroot_sfs_container_lock()
# @extern int newroot_sfs_container_unlock()
# @extern int newroot_sfs_container_downsize()
# @extern int newroot_sfs_container_finalize()


#@section functions

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
   inonfatal sfs_container_mount_writable_rooted \
      "${1:?}" "${v0:?}" "${3:-100}" "${NEWROOT}/aufs_root"
}

# @function_alias newroot_sfs_container_mount_writeable()
#  renames newroot_sfs_container_mount_writable()
newroot_sfs_container_mount_writeable() {
   newroot_sfs_container_mount_writable "$@"
}

#@section functions_export

# @extern int newroot_sfs_container_mount()          -- sfs_name, mp
# @extern void newroot_sfs_container_init()          -- mp, size_m
# @extern int newroot_sfs_container_import()         -- sfs_file, sfs_name
# @extern int newroot_sfs_container_lock()
# @extern int newroot_sfs_container_unlock()
# @extern int newroot_sfs_container_downsize()
# @extern int newroot_sfs_container_finalize()
# @extern int newroot_sfs_container_avail()
# @extern int newroot_sfs_container_mount_writable() -- sfs_name, mp, size, aufs_root
