#@section functions

# int disk_mounted ( [disk], [mp] )
#
#  This function has 3 (4) uses cases:
#
#  if disk and mp are set:
#   Returns 0 if disk is mounted at mp, else 1.
#
#  if only disk is set:
#   Returns 0 if disk is mounted, else 1.
#
#  if only mp is set (and first arg is ""):
#   Returns 0 if <anything> is mounted at mp, else 1.
#
#  else
#   Returns 2 - not enough args.
#
#  A return value of 1 could also mean that /proc/self/mounts
#  is not accessible.
#
disk_mounted() {
   local M="/proc/self/mounts"
   if [ -z "${2-}" ]; then
      if [ -n "${1-}" ]; then
         grep -q -- ^"${1}[[:blank:]]" "${M}" || return 1
      else
         return 2
      fi
   elif [ -z "${1-}" ]; then
      # $2 not empty
      grep -q -E -- ^"\S+\s+${2}\s" "${M}" || return 1
   else
      # neither $1 nor $2 empty
      grep -q -- ^"${1}[[:blank:]]${2}[[:blank:]]" "${M}" || return 1
   fi
   return 0
}

# @function_alias is_mountpoint ( mp ) is disk_mounted ( "", mp )
#
is_mountpoint() { disk_mounted "" "$@"; }

# @function_alias is_mounted ( mp ) is disk_mounted ( "", mp )
#
is_mounted() { disk_mounted "" "$@"; }

# int fstype_supported ( *fstype )
#
#  Returns 0 if all given fstypes are supported (appear in /proc/filesystems),
#  else 1. Also returns 0 if the fstype list is empty.
#  The result for the empty string is undefined.
#
fstype_supported() {
   while [ $# -gt 0 ]; do
      grep -q -- [[:blank:]]${1-}$ /proc/filesystems || return 1
      shift
   done
   return 0
}

# int mountpoint_in_fstab ( mp, **FSTAB_FILE=/etc/fstab )
#
#  Returns 0 if the given mountpoint appears in %FSTAB_FILE, else 1.
#  Returns 2 if %mp was empty.
#
mountpoint_in_fstab() {
   if [ -z "${1-}" ]; then
      return 2
   elif \
      grep -q -E -- ^"\S+\s+${1}[/]*\s+" "${FSTAB_FILE:-/etc/fstab}"
   then
      return 0
   else
      return 1
   fi
}
