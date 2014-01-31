#@section functions

# int initramfs_sleep ( *time )
#
#  Sleeps for the specified amount of time.
#
initramfs_sleep() {
   ${LOGGER} --level=DEBUG "(initramfs) sleeping for $*"
   sleep "$@"
}

# int initramfs_debug_sleep ( *time, **INITRAMFS_DEBUG_SLEEP=y )
#
#  Sleeps for the specified amount of time if INITRAMFS_DEBUG_SLEEP
#  is set to y.
#
initramfs_debug_sleep() {
   if [ "${INITRAMFS_DEBUG_SLEEP:-y}" = "y" ]; then
      ${LOGGER} --level=INFO "(initramfs debug) sleeping for $*"
      sleep "$@"
   else
      return 0
   fi
}

# int initramfs_rootdelay ( **CMDLINE_ROOTDELAY= )
#
#  rootdelay sleeping.
#
initramfs_rootdelay() {
   if [ -n "${CMDLINE_ROOTDELAY-}" ]; then
      dolog_info "rootdelay: sleeping for ${CMDLINE_ROOTDELAY} seconds"
      sleep "${CMDLINE_ROOTDELAY}"
   else
      return 0
   fi
}

# int initramfs_kmsg_redirect ( **CONSOLE )
#
#  Sets up stderr/stdout redirection to /dev/kmsg.
#
initramfs_kmsg_redirect() {
   exec >/dev/kmsg 2>&1 <${CONSOLE:?}
}

# void initramfs_suppress_printk()
#
#  Stops kernel messages from "polluting" the console.
#
initramfs_suppress_printk() {
   echo 0 > /proc/sys/kernel/printk
}

# void initramfs_switch_root ( *argv ), raises initramfs_die()
#
#  Switches to NEWROOT.
#
initramfs_switch_root() {
   : ${CMDLINE_INIT:=/sbin/init}

   [ -x "${NEWROOT}/${CMDLINE_INIT#/}" ] || \
      initramfs_die "cannot locate ${CMDLINE_INIT} in ${NEWROOT}"

   if [ $# -eq 0 ] && [ -n "${INIT_ARGV+y}" ]; then
      # this does not handle whitespace in INIT_ARGV
      set -- ${INIT_ARGV}
   fi

   local opts=""
#   if \
#      [ -n "${CONSOLE-}" ] && switch_root -h 2>&1 | grep -E -- '^\s+-c[,]?\s+'
#   then
#      opts="${opts} -c ${CONSOLE}"
#   fi

   exec switch_root ${opts} "${NEWROOT}" ${CMDLINE_INIT} "$@"
   initramfs_die "switch_root failed"
}

# int initramfs_copy_file ( src, dest )
#
#  Copies a file verbosely using rsync or cp. rsync is preferred.
#
initramfs_copy_file() {
##   if [ -x /usr/bin/rsync ]; then
##      ${LOGGER} -0 --level=DEBUG "Copying ${1} -> ${2} using /usr/bin/rsync"
##
##      /usr/bin/rsync -L -W --progress -- "${1}" "${2}"
##
   if qwhich rsync; then
      ${LOGGER} -0 --level=DEBUG "Copying ${1} -> ${2} using rsync"

      rsync -L -W --progress -- "${1}" "${2}"

   else
      ${LOGGER} -0 --level=INFO "Copying ${1} -> ${2} using cp"

      cp -v -L  -- "${1}" "${2}"

   fi
}
