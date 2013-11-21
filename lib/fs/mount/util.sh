#@section functions_public

# int unmount_if_mounted ( mp, [dev] )
#
#  Unmounts mp if
#  * dev is mounted at mp
#  * dev is not set and a device is mounted at mp
#
#  Returns 0 ifnothing done (mp not mounted or mp not specified),
#  else umount's return value, which is 0 if mp has been unmounted.
#
unmount_if_mounted() {
   disk_mounted "${2-}" "${1-}" || return 0
   do_umount "${1}"
}

# @function_alias umount_if_mounted() renames unmount_if_mounted (...)
#
umount_if_mounted() { unmount_if_mounted "$@"; }

# @function_alias unmount() renames umount (...)
#
unmount() { umount "$@"; }
