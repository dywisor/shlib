# void initramfs_vars ( **<see function body> )
#
#  Initializes some variables using initramfs-specific code.
#
initramfs_vars() {
   # default path
   export PATH="/sbin:/usr/sbin:/bin/usr/bin:/busybox"

   if [ -z "${DEBUG-}" ]; then
      [ -e /DEBUG ] && DEBUG=y || DEBUG=n
   fi

   if [ -z "${VERBOSE-}" ]; then
      [ -e /VERBOSE ] && VERBOSE=y || VERBOSE=n
   fi

   if [ -z "${QUIET-}" ]; then
      [ -e /QUIET ] && QUIET=y || QUIET=n
   fi

   if [ -z "${NO_COLOR-}" ] && [ -e /NO_COLOR ]; then
      NO_COLOR=y
   fi

   [ -n "${TERM-}" ] || export TERM=linux

   if [ -z "${CONSOLE-}" ]; then
      if [ -e /SERIAL_CONSOLE ]; then
         CONSOLE=/dev/ttyS0
         NO_COLOR=y
      else
         CONSOLE=/dev/tty1
      fi
   fi

   : ${PRINT_FUNCTRACE:=y}

   : ${LOGFILE=/init.log}

   : ${MOUNTOPTS_APPEND=-n}
}

# @implicit void main()
#
#  Calls initramfs_vars() if the id of this process is 1.
#
if [ $$ -eq 1 ]; then
   initramfs_vars
fi
