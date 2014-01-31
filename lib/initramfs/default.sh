#@section functions

# void initramfs_default_start (
#    **SUPPRESS_PRINTK=y,
#    **INIT_NEWROOT=y,
#    **NEWROOT_TYPE=disk
# )
#
#  Common initramfs start code, performs the following actions:
#
#  * let DEVFS_TYPE default to mdev (personal preference)
#  * intialize the baselayout
#  * suppress kernel messages unless SUPPRESS_PRINTK is set and not 'y'
#  * parse /proc/cmdline
#  * initialize further depending on NEWROOT_TYPE and INIT_NEWROOT
#  when disk =>
#  ** mount the rootfs (mandatory)
#  ** mount /etc (optional)
#  ** call newroot_premount_all() (optional)
#  when disk-hybrid =>
#  ** mount the rootfs (mandatory)
#  when liram =>
#  ** call liram_init() which does whatever has been configured
#  By default, this will create the whole rootfs in a tmpfs.
#
initramfs_default_start() {
   : ${DEVFS_TYPE:=mdev}

   irun initramfs_baselayout
   if [ "${SUPPRESS_PRINTK:-y}" = "y" ]; then
      inonfatal initramfs_suppress_printk
   fi
   irun cmdline_parse

   if [ "${CMDLINE_WANT_SHELL:-n}" = "y" ]; then
      initramfs_launch_user_shell

   else
      irun initramfs_rootdelay

      if [ "x${INIT_NEWROOT=y}" = "xy" ]; then
         case "${NEWROOT_TYPE=disk}" in
            disk)
               # rootfs, /etc, premount(s)
               irun newroot_mount_all
               [ "${NEWROOT_SETUP:=y}" != "y" ] || irun newroot_setup_all
            ;;
            disk-hybrid)
               # rootfs
               irun newroot_mount_rootfs
            ;;
            liram)
               irun liram_init
            ;;
         esac
      fi
   fi
}

# void initramfs_default_end (
#    *init_argv,
#    **CMDLINE_INIT=/sbin/init,
#    **NEWROOT
# )
#
#  Common initramfs end code, brings down networking (if set up),
#  verifies that newroot's init exists, copies the logfile to newroot,
#  stops the basemounts and executes switch_root afterwards.
#
initramfs_default_end() {
   : ${CMDLINE_INIT:=/sbin/init}

   if \
      [ "${INITRAMFS_KEEP_NET:-n}" != "y" ] && \
      [ "${INITRAMFS_HAVE_NET:-n}" = "y" ]
   then
      inonfatal initramfs_net_setup down
   fi

   # double tap!
   #  CMDLINE_INIT will be checked twice when using initramfs_default_end()
   #
   if [ -x "${NEWROOT}/${CMDLINE_INIT#/}" ]; then
      # copy the logfile to newroot
      #  (current "version", further messages wont be readable in newroot)
      # move / unmount basemounts
      # switch to newroot
      #
      inonfatal newroot_import_logfile
      basemounts_stop
      initramfs_switch_root "$@"
   else
      initramfs_die "cannot locate ${CMDLINE_INIT} in ${NEWROOT}"
   fi
}

# void initramfs_default_main ( *init_argv, **... )
#
#  The default initramfs main function.
#   (initramfs_default_start() followed by initramfs_default_end(...))
#
#  Basic init scripts just need to set some variables (or none, accepting all
#  defaults) and call this function afterwards, which will bring up the system.
#
initramfs_default_main() {
   initramfs_default_start
   initramfs_default_end "$@"
   initramfs_die "unreachable die() statement"
}
