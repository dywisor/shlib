# int domount ( *argv, **MOUNT=mount, **MOUNTOPTS_APPEND= )
#
#  Wrapper function that applies extra options to mount().
#
do_mount() {
   ${LOGGER:-true} -0 --level=DEBUG "${MOUNT:-mount} ${MOUNTOPTS_APPEND-} $*"
   ${MOUNT:-mount} ${MOUNTOPTS_APPEND-} "$@"
}

# @function_alias domount() renames do_mount()
domount() { do_mount "$@"; }

# domount_fs ( mp, fs, opts=, fstype=auto )
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
