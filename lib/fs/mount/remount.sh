#@section functions

# int remount ( *mp, **REMOUNT_MODE ), raises function_die()
#
#  Remounts the given mountpoints. Returns on first failure.
#
remount() {
   [ -n "${REMOUNT_MODE-}" ] || function_die "REMOUNT_MODE must be set."
   while [ $# -gt 0 ]; do
      if [ -n "${1-}" ]; then
         veinfo "Remounting ${1} with mode=${REMOUNT_MODE}"
         do_mount "${1}" -o remount,${REMOUNT_MODE} || return
      fi
      shift
   done
}

# int remount_ro ( *mp )
#
#  Remounts the given mountpoints readonly.
#
remount_ro() { REMOUNT_MODE="ro" remount "$@"; }

# int remount_rw ( *mp )
#
#  Remounts the given mountpoints in read-write mode.
#
remount_rw() { REMOUNT_MODE="rw" remount "$@"; }
