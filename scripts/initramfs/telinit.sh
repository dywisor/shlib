#!/bin/busybox ash

# stop logging
for p in klogd syslogd; do
   /bin/busybox killall "${p}"
done

# unmount what's left
/bin/busybox sync

if [ ! -e /proc/self ] || [ -e /proc/swaps ]; then
   /bin/busybox swapoff -a
fi

/bin/busybox umount -n -a -r

# call real telinit (if any) or poweroff/reboot

if [ "${0}" != "/sbin/telinit" ] && [ -x "/sbin/telinit" ]; then
   /sbin/telinit "$@"
elif [ "${1-}" = "0" ]; then
   /bin/busybox poweroff -f
elif [ "${1-}" = "6" ]; then
   /bin/busybox reboot -f
fi
