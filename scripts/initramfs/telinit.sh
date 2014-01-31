#!/bin/busybox ash

# int xprog ( prog_name, *argv )
#
xprog() {
   [ -n "${1-}" ] || return 100
   local x name="${1}"; shift

   for x in /bin/${name} /sbin/${name}; do
      if [ -x "${x}" ]; then
         ${x} "$@"
         return ${?}
      fi
   done

   # fall back to busybox
   /bin/busybox ${name} "$@"
}


# stop logging
for p in klogd syslogd; do
   xprog killall "${p}"
done

# unmount what's left
xprog sync

if [ ! -e /proc/self ] || [ -e /proc/swaps ]; then
   xprog swapoff -a
fi

xprog umount -n -a -r

# call real telinit (if any) or poweroff/reboot

if [ "${0}" != "/sbin/telinit" ] && [ -x "/sbin/telinit" ]; then
   /sbin/telinit "$@"
elif [ "${1-}" = "0" ]; then
   xprog poweroff -f
elif [ "${1-}" = "6" ]; then
   xprog reboot -f
fi
