#@section funcdef

# @funcdef int|void domount_mp <function name> ( mp, *args )
#
#  Function that mounts the first arg, optionally with the given args.
#

#@section functions

# @private void domount__logger ( log_level, message, **LOGGER=true )
#
#  Logs a message with the given log level if %LOGGER is available.
#
domount__logger() {
   if [ -z "${2-}" ]; then
      true

   elif [ "${LOGGER:-true}" != "true" ]; then
      ${LOGGER:?} -0 --level="${1:-UNDEF}" "${2}"

   elif [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
      case "${1:-UNDEF}" in
         'WARN')
            ewarn "${2}"
         ;;
         'ERROR')
            eerror "${2}"
         ;;
      esac
   fi
   return 0
}

# int do_mount ( *argv, **MOUNT=mount, **MOUNTOPTS_APPEND= )
#
#  Wrapper function that applies extra options to mount().
#
do_mount() {
   domount__logger DEBUG "${MOUNT:-mount} ${MOUNTOPTS_APPEND-} $*"
   ${MOUNT:-mount} ${MOUNTOPTS_APPEND-} "$@"
}

# @function_alias domount() renames do_mount()
domount() { do_mount "$@"; }

# int domount_fs ( mp, fs, opts=, fstype=auto )
#
#  Wrapper function for mounting filesystems.
#  Calls dodir_clean() before mounting.
#
domount_fs() {
   if [ -n "${3-}" ]; then
      dodir_clean "${1:?}" && \
         do_mount -t "${4:-auto}" -o "${3}" "${2}" "${1}"
   else
      dodir_clean "${1:?}" && \
         do_mount -t "${4:-auto}" "${2}" "${1}"
   fi
}

# int do_umount ( *argv, **UMOUNT=umount, **MOUNTOPTS_APPEND= )
#
#  Wrapper function that applies extra options to umount().
#
do_umount() {
   ${UMOUNT:-umount} ${MOUNTOPTS_APPEND-} "$@"
}

# @function_alias do_unmount() copies do_umount()
#
do_unmount() {
   ${UMOUNT:-umount} ${MOUNTOPTS_APPEND-} "$@"
}

# @domount_mp int domount2 ( mp, *args, **MOUNT=mount, **MOUNTOPTS_APPEND= )
#
#  Checks whether %mp is already mounted and returns immediately if that's
#  the case (with retcode 0).
#
#  Then, checks whether %mp appears in /etc/fstab and mounts it with
#  the options listed there.
#  Otherwise, uses the given %args for mounting %mp if it doesn't appear
#  in /etc/fstab.
#
#  Note:
#  * /proc has to be mounted before calling this function
#  * %F_FSTAB is ignored by this function.
#  * /etc/fstab should (but doesn't have to) exist
#
domount2() {
   local mp="${1-}"
   local F_FSTAB="/etc/fstab"

   if [ -z "${mp}" ]; then
      domount__logger ERROR "domount2($*): bad usage"
      return 65

   elif ! dodir_clean "${mp}"; then
      domount__logger ERROR "failed to create mountpoint dir ${mp}"
      return 66

   elif is_mounted "${mp}"; then
      domount__logger INFO "${mp} is already mounted."
      return 0

   elif mountpoint_in_fstab "${mp}"; then
      domount__logger DEBUG "mounting ${mp} from fstab"
      do_mount "${mp}"
      return ${?}

   elif [ -n "$*" ]; then
      domount__logger DEBUG "mounting ${mp} from argv"
      shift && do_mount "$@" "${mp}"
      return ${?}

   else
      domount__logger WARN \
         "domount2($*): cannot mount ${mp}: not in fstab and no args."
      return 67
   fi
}

# @function_alias domount_smart() renames domount2()
#
# TODO: find a proper name for domount2().
#
domount_smart() { domount2 "$@"; }


# @domount_mp int domount3 ( mp, *args )
#
#  Wrapper for calling do_mount ( *args, mp ).
#
domount3() {
   local mp="${1-}"
   if [ -n "${mp}" ]; then
      shift
      do_mount "$@" "${mp}"
   else
      domount__logger ERROR "domount3($*): bad usage"
      return 65
   fi
}

#@section module_init_vars
: ${F_DOMOUNT_MP:=domount3}
