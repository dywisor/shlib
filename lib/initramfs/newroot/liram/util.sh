## functions from initramfs/newroot/squashfs_container{,_aufs}

# @extern void newroot_sfs_container_init()
# @extern int  newroot_sfs_container_mount()
# @extern int  sfs_container_avail()
# @extern int  sfs_container_downsize()
# @extern int  sfs_container_finalize()
# @extern int  sfs_container_import()
# @extern void sfs_container_init()
# @extern int  sfs_container_lock()
# @extern int  sfs_container_mount()
# @extern int  sfs_container_unlock()
# @extern int sfs_container_mount_writable()
# @extern int newroot_sfs_container_mount_writable()

# int liram_sfs_container_import ( name, sfs_name=name, **v0! )
#
#  Imports a squashfs file referenced by name into the current squashfs
#  file container. Creates one if necessary.
#
#  Stores the path to the imported squashfs file in the %v0 variable and
#  returns 0 if it has been imported, else sets v0="" and returns a
#  non-zero value.
#
#  The actual copy function sfs_container_import() has to succeed,
#  else this functions calls die().
#
#  Expects to be called during liram_populate().
#
liram_sfs_container_import() {
   if liram_get_squashfs "${1:?}"; then
      local sfs_file="${v0}"
      v0=

      sfs_container_avail || sfs_container_init "${NEWROOT}//SFS/liram"

      if irun sfs_container_import "${sfs_file}" "${2:-${1}}"; then
         v0="${sfs_file}"
         return 0
      else
         v0=
         return 150
      fi
   else
      v0=
      return 1
   fi
}


# void liram_scan_files ( sync_root:=/tmp/liram_$$/filescan )
#
#  Scans for tarball and squashfs files.
#
#  Relevant variables: TARBALL_SCAN_NAMES and SQUASHFS_SCAN_NAMES.
#
liram_scan_files() {
   local SYNC_ROOT="${1:-/tmp/liram_$$/filescan}"
   liram_scan_tarball "${SYNC_ROOT}/tarball"
   liram_scan_squashfs "${SYNC_ROOT}/squashfs"
   return 0
}

# @extern int liram_get_tarball  ( name )
# @extern int liram_get_squashfs ( name )
# @extern int liram_get_sfs      ( name )

# int liram_unpack_name ( name, dest="" )
#
#  Unpacks a tarball referenced by name into NEWROOT/dest.
#
liram_unpack_name() {
   local v0
   inonfatal liram_get_tarball "${1:?}" && \
      inonfatal newroot_unpack_tarball "${v0:?}" "${2-}"
}

# int liram_unpack_replace_name ( name, dest="", backup="", delete_backup="" )
#
#  Like liram_unpack_name(), but replaces NEWROOT/dest instead of
#  overwriting it.
#
liram_unpack_replace_name() {
   local v0
   inonfatal liram_get_tarball "${1:?}" && \
      inonfatal newroot_unpack_tarball_replace "${v0:?}" "${2-}" "${3-}" "${4-}"
}

# int liram_unpack_default ( name, tarball_file=<detect> ),
#  raises initramfs_die()
#
#  Unpacks a tarball into its default directory (depending on name).
#  Optionally searches for the tarball if no second arg supplied.
#
#  Returns 0 on success.
#
liram_unpack_default() {
   local dest
   case "${1-}" in
      '')
         return 20
      ;;
      'rootfs')
         dest="/"
      ;;
      'etc'|'usr'|'var')
         dest="/${1}"
      ;;
      'home')
         # home could be /home, /var/users, ...
         if [ -n "${NEWROOT_HOME_DIR-}" ]; then
            dest="${NEWROOT_HOME_DIR}"
         else
            dest="/home"
         fi
      ;;
      'scripts'|'sh')
         dest="/sh"
      ;;
      'log')
         dest="/var/log"
      ;;
      *)
         initramfs_die "unknown dest dir for tarball name ${1}"
      ;;
   esac
   if [ -n "${2-}" ]; then
      inonfatal newroot_unpack_tarball "${2}" "${dest}"
   else
      local v0
      inonfatal liram_get_tarball "${1:?}" && \
      inonfatal newroot_unpack_tarball "${v0}" "${dest}"
   fi
}

# int liram_unpack_name_default ( *name, **LIRAM_UNPACK_NAME_TRY=n ),
#  raises initramfs_die()
#
#  Unpacks zero or more tarballs referenced by name into their default
#  destition (e.g. "rootfs" => "/", "usr" => "/usr").
#
#  Returns on first failure if LIRAM_UNPACK_NAME_TRY is not set to 'y',
#  else continues. LIRAM_UNPACK_NAME_TRY == 'y' also means that it's optional
#  whether the tarball exists or not.
#
liram_unpack_name_default() {
   local v0 rc=0
   while [ $# -gt 0 ]; do
      if [ -z "${1-}" ]; then

         true

      elif liram_get_tarball "${1:?}"; then

         if liram_unpack_default "${1}" "${v0}"; then
            true
         elif [ "${LIRAM_UNPACK_NAME_TRY:-n}" = "y" ]; then
            rc=2
         else
            return 1
         fi

      elif [ "${LIRAM_UNPACK_NAME_TRY:-n}" != "y" ]; then

         return 3

      fi
      shift
   done
   return ${rc}
}

# int liram_unpack_all_default(), raises initramfs_die()
#
#  Unpacks whatever available to its default location.
#
#  !!! This will fail if you add unknown entries to the TARBALL_SCAN_NAMES
#      variable.
#
liram_unpack_all_default() {
   irun liram_unpack_name_default ${TARBALL_SCAN_NAMES-}
}

# int liram_unpack_optional (
#    name, tarball_file=<detect>, dest=<detect>, **v0!
# )
#
#  Unpacks an optional tarball using whatever function that fits,
#  either newroot_unpack_tarball() or liram_unpack_default().
#
#  Returns 0 if a tarball has been extracted, else 1 (no such tarball).
#
#  Note: While existence of the file is optional, unpacking is not.
#        This function will die if the tarball exists but cannot be extracted.
#
liram_unpack_optional() {
   if [ -n "${2-}" ]; then
      v0="${2}"
   elif ! inonfatal liram_get_tarball "${1:?}"; then
      return 0
   fi

   if [ "x${3-B}" = "x${3-A}" ]; then
      irun liram_unpack_default "${1:?}" "${v0}"
   else
      irun newroot_unpack_tarball "${v0}" "${3}"
   fi
}
