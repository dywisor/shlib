#@section functions

# void newroot_chroot_prepare ( **NEWROOT )
#
#  Prepares the newroot chroot (essential mounts etc.)
#
#  Note that this function will fail if NEWROOT is readonly and /proc or
#  /dev is/are missing.
#
newroot_chroot_prepare() {
   irun dodir "${NEWROOT}/proc" "${NEWROOT}/dev"
   imount -t proc -o ${PROCFS_OPTS:?} proc "${NEWROOT}/proc"
   # not rbind
   imount -o bind /dev "${NEWROOT}/dev"
}

# void newroot_chroot_leave ( **NEWROOT )
#
#  Leaves the newroot chroot (unmounts /dev, /proc).
#
newroot_chroot_leave() {
   iumount "${NEWROOT}/dev"
   iumount "${NEWROOT}/proc"
}

# int newroot_chroot_exec ( *cmdv, **NEWROOT )
#
#  Runs a command in the newroot chroot.
#  You have to call newroot_chroot_prepare() before / newroot_chroot_leave()
#  after this function.
#
newroot_chroot_exec() {
   [ -n "${*}" ] || return 253
   chroot "${NEWROOT}" "$@"
}

# int newroot_chroot ( *cmdv, **NEWROOT )
#
#  Prepares the newroot chroot, executes *cmdv and leaves the chroot.
#
#  Returns the command's exit code (or 253 if no command given).
#
newroot_chroot() {
   local rc
   [ -n "${*}" ] || return 253
   newroot_chroot_prepare
   chroot "${NEWROOT}" "$@"
   rc=${?}
   newroot_chroot_leave
   return ${rc}
}
