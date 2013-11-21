#@section functions_export

# @extern int  newroot_premount ( mp )
# @extern void newroot_premount_all()


#@section functions

# void newroot_mount_rootfs ( **CMDLINE_ROOT... )
#
#  Mounts the rootfs.
#
newroot_mount_rootfs() {
   [ -n "${CMDLINE_ROOT-}" ] || initramfs_die "CMDLINE_ROOT is not set."

   local opts="${CMDLINE_ROOTFSFLAGS-}"
   if [ "${CMDLINE_ROOT_RO:-y}" = "y" ]; then
      opts="${opts}${opts:+,}ro"
   else
      opts="${opts}${opts:+,}rw"
   fi

   imount_disk \
      "${NEWROOT?}" "${CMDLINE_ROOT}" \
      "${opts}" "${CMDLINE_ROOTFSTYPE:-auto}" "${CMDLINE_ROOT_FSCK:-y}"
}

# void newroot_mount_etc ( **CMDLINE_ETC... )
#
#  Mounts <NEWROOT>/etc.
#
newroot_mount_etc() {
   ## premount() cannot be used for mounting /etc
   ## since it's very likely that <NEWROOT>/etc/fstab does not exist
   [ -n "${CMDLINE_ETC-}" ] || initramfs_die "CMDLINE_ETC is not set."

   local opts="${CMDLINE_ETCFSFLAGS-}"
   if [ "${CMDLINE_ETC_RO:-y}" = "y" ]; then
      opts="${opts}${opts:+,}ro"
   else
      opts="${opts}${opts:+,}rw"
   fi

   imount_disk \
      "${NEWROOT:?}/etc" "${CMDLINE_ETC}" \
      "${opts}" "${CMDLINE_ETCFSTYPE:-auto}" "${CMDLINE_FSCK:-y}"
}

# void newroot_mount ( *name_or_mp )
#
#  Mounts zero or more directories in NEWROOT.
#
newroot_mount() {
   while [ $# -gt 0 ]; do
      case "${1}" in
         rootfs|/)
            newroot_mount_rootfs
         ;;
         etc|/etc)
            newroot_mount_etc
         ;;
         usr)
            irun newroot_premount /usr
         ;;
         '')
            true
         ;;
         *)
            irun newroot_premount "${1}"
         ;;
      esac
      shift
   done
}

# void newroot_mount_all()
#
#  Mount whatever has been configured by /proc/cmdline.
#  CMDLINE_ROOT is mandatory.
#
newroot_mount_all() {
   newroot_mount_rootfs
   [ -z "${CMDLINE_ETC-}" ] || newroot_mount_etc
   newroot_premount_all
}
