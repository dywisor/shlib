# @extern int dodir (...)

: ${NEWROOT:=/newroot}

# void newroot_doprefix ( fspath, **NEWROOT )
#
#  Prefixes fspath with NEWROOT and stores the result in v0.
#  Also eliminates slash characters '/' at the end.
#
newroot_doprefix() {
   if [ $# -lt 2 ]; then
      fs_doprefix "${1-}" "${NEWROOT}"
   else
      local f="${1}"
      shift
      fs_doprefix "${f}" "${NEWROOT}" "$@"
   fi
}

# int newroot_dodir ( *dir, ..., **DODIR_PREFIX, **NEWROOT )
#
#  Creates zero or more directories in NEWROOT.
#  Transparently handles the DODIR_PREFIX variable.
#
#  See dodir() in fs/dodir for advanced usage.
#
newroot_dodir() {
   local v0
   fs_doprefix "${DODIR_PREFIX-}" "${NEWROOT}"
   DODIR_PREFIX="${v0}" dodir "$@"
}

# void newroot_bind_prefix_function ( function, newroot_function )
#
#  Creates a new function <newroot_function>() that calls
#  fs_doprefix_call ( <NEWROOT>, <function>, ... ).
#
newroot_bind_prefix_function() {
   eval "${2:-newroot_${1:?}}() { fs_doprefix_call \"\${NEWROOT}\" ${1:?} \"\$@\"; }"
}

# int newroot_dofile ( file, str=, dofile_create=**DOFILE_CREATE=y )
#
newroot_dofile() { fs_doprefix_call "${NEWROOT}" dofile "$@"; }

# int newroot_import_logfile ( **LOGFILE, **NEWROOT_LOGFILE_DEST= )
#
#  Tries to copy the logfile to NEWROOT_LOGFILE_DEST, if set, then tries
#  to copy it to standard places (in that order):
#  * /status
#  * /var/log
#  * /tmp
#  * /
#
#  Does nothing if LOGFILE is not set or does not exist.
#
newroot_import_logfile() {
	[ -n "${LOGFILE-}" ] && [ -f "${LOGFILE}" ] || return 0

   ${LOGGER} -0 --level=INFO --time "copying logfile into ${NEWROOT}"

   local dest

	if [ -n "${NEWROOT_LOGFILE_DEST-}" ]; then
      local v0
      if \
         newroot_doprefix "${NEWROOT_LOGFILE_DEST}" && \
         dest="${v0}" && \
         dodir_clean "${dest%/*}" && \
         cp -L -- "${LOGFILE}" "${dest}"
      then
         return 0
      fi
	fi

   local destdir
   for destdir in '/status' '/var/log' '/tmp' '/'; do
      destdir="${NEWROOT}/${destdir#/}"
      if [ -d "${destdir%/}" ]; then
         if cp -L -- "${LOGFILE}" "${destdir%/}/initramfs.log"; then
            return 0
         fi
      fi
   done

   ewarn "could not copy the log file, please fix this"
   initramfs_debug_sleep 5
   return 1
}
