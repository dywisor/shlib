# int domount ( *argv, **MOUNT=mount, **MOUNTOPTS_APPEND= )
#
#  Wrapper function that applies extra options to mount().
#
domount() {
   ${MOUNT:-mount} ${MOUNTOPTS_APPEND-} "$@"
}

# @function_alias do_mount() copies domount()
do_mount() {
   ${MOUNT:-mount} ${MOUNTOPTS_APPEND-} "$@"
}

# domount_fs ( mp, fs, opts=defaults, fstype=auto )
#
#  Wrapper function for mounting filesystems.
#  Calls dodir_clean() before mounting.
#
domount_fs() {
   dodir_clean "${1:?}" && \
      do_mount -t "${4:-auto}" -o "${3:-defaults}" "${2}" "${1}"
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
