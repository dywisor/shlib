#@section functions

# int newroot_unpack_tarball ( tarball_file, dest="/" )
#
#  Unpacks a tarball file into NEWROOT/dest.
#
newroot_unpack_tarball() {
   local v0
   newroot_doprefix "${2-}"
   initramfs_unpack_tarball "${1:?}" "${v0?}"
}

# int newroot_unpack_tarball_replace (
#    tarball_file, dest="/", backup=, delete_backup=n
# )
#
#  Replaces NEWROOT/dest with the contents of tarball_file, optionally
#  moving NEWROOT/dest to NEWROOT/backup just before unpacking.
#
#  NEWROOT/dest will be removed (before unpacking) if backup is not set.
#
#  The backup will not be deleted unless successful
#  and delete_backup is set to 'y'.
#
#  Returns 0 if NEWROOT/dest has been replaced.
#  A non-zero return value indicates failure.
#
#
newroot_unpack_tarball_replace() {
   local v0 newroot_dest newroot_bak=
   newroot_doprefix "${2:?}"
   newroot_dest="${v0}"

   if [ $# -gt 2 ] && [ -n "${3-}" ]; then
      newroot_doprefix "${3-}"
      newroot_bak="${v0}"
   fi

   if [ ! -f "${1:?}" ]; then
      # tarball does not exist, why did you call this function?
      return 90

   elif [ "${newroot_dest%/}" = "${NEWROOT%/}" ]; then
      ## initramfs_die could return (by user request)
      initramfs_die "Attempted to replace ${NEWROOT}" || return

   elif [ "x${newroot_bak%/}" = "x${NEWROOT%/}" ]; then
      initramfs_die "Attempted to use ${NEWROOT} as backup directory." || return

   elif [ -d "${newroot_dest}" ]; then
      # dest exists as dir, that's okay
      if [ "${newroot_bak}" ]; then
         inonfatal mv -n -- "${newroot_dest}" "${newroot_bak}" || return
      else
         inonfatal rm -r -- "${newroot_dest}" || return
      fi
      sync

   elif [ -e "${newroot_dest}" ]; then
      # dest exists, but is not a dir, that's not okay
      return 95

   elif [ -h "${newroot_dest}" ]; then
      # dest is a broken symlink, fix it
      ${LOGGER} --level=WARN "Removing broken symlink '${newroot_dest}'."
      inonfatal rm "${newroot_dest}" || return
   fi

   inonfatal dodir_clean "${newroot_dest}" || return

   if inonfatal initramfs_unpack_tarball "${1}" "${newroot_dest}"; then
      # all went well, "finalize" $newroot_dest and remove $newroot_bak if
      # $4 is set to y

      if [ -f "${newroot_dest}/__REPLACE_FAILED__" ]; then
         inonfatal rm -- "${newroot_dest}/__REPLACE_FAILED__"
      fi

      if [ "${newroot_bak}" ] && [ "${4:-n}" = "y" ]; then
         inonfatal rm -r "${newroot_bak}"
      fi

      sync
      return 0
   else
      # try to recover from backup dir

      local rc=$?

      if [ "${newroot_bak}" ]; then
         if [ -d "${newroot_dest}" ]; then
            inonfatal rm -r -- "${newroot_dest}"
         fi
         mv -f -T -- "${newroot_bak}" "${newroot_dest}"
      fi

      sync
      return ${rc}
   fi
}

# @function_alias int newroot_replace_etc ( tarball_file )
#  is newroot_unpack_tarball_replace ( tarball_file, "/etc", "/old-etc", "n" )
#
#  Replaces newroot/etc with the contents of tarball_file.
#  Creates a backup of the old etc dir in/at newroot/old-etc.
#
newroot_replace_etc() {
   newroot_unpack_tarball_replace "${1:?}" "/etc" "/old-etc" "n"
}
