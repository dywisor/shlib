#@section header
# this module provides newroot-specific function wrappers
#
# quickref
# int newroot_sfs_container_mount()          -- sfs_name, mp
# void newroot_sfs_container_init()          -- mp, size_m
# int newroot_sfs_container_import()         -- sfs_file, sfs_name
# int newroot_sfs_container_lock()
# int newroot_sfs_container_unlock()
# int newroot_sfs_container_downsize()
# int newroot_sfs_container_finalize()
# int newroot_sfs_container_avail()


#@section functions

# int newroot_sfs_container_mount ( sfs_name, mp, **SFS_CONTAINER )
#
#  Prefixes mp with %NEWROOT and calls
#  sfs_container_mount ( sfs_name, newroot_mp ).
#
newroot_sfs_container_mount() {
   local v0
   newroot_doprefix "${2:?}"
   inonfatal sfs_container_mount "${1}" "${v0}"
}

# void newroot_sfs_container_init ( mp, ... )
#
#  Prefixes mp with $NEWROOT and calls
#  sfs_container_init ( newroot_mp, ... ) afterwards.
#
newroot_sfs_container_init() {
   local v0
   newroot_doprefix "${1:?}"
   shift
   irun sfs_container_init "${v0}" "$@"
}

# @function_alias newroot_sfs_container_import (...)
#  is inonfatal sfs_container_import (..., **F_SFS_CONTAINER_COPYFILE )
#
newroot_sfs_container_import() {
   local F_SFS_CONTAINER_COPYFILE=newroot_sfs_container__copy_file
   inonfatal sfs_container_import "$@"
}

# @private int newroot_sfs_container__copy_file ( src, dest )
#
#  Copies a squashfs file.
#
newroot_sfs_container__copy_file() {
   if initramfs_copy_file "${1}" "${2}"; then
      inonfatal chmod 0400 "${2}"
      inonfatal chown 0.0 "${2}"
      return 0
   else
      return ${?}
   fi
}

newroot_sfs_container_avail()    { sfs_container_avail "$@"; }

newroot_sfs_container_lock()     { inonfatal sfs_container_lock     "$@"; }
newroot_sfs_container_unlock()   { inonfatal sfs_container_unlock   "$@"; }
newroot_sfs_container_downsize() { inonfatal sfs_container_downsize "$@"; }
newroot_sfs_container_finalize() { inonfatal sfs_container_finalize "$@"; }
