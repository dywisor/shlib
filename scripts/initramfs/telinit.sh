#!/bin/busybox ash

# stop logging
for p in klogd syslogd; do
   /bin/busybox killall "${p}"
done

# unmount what's left
/bin/busybox umount -a -r
/bin/busybox swapoff -a

case "${1-}" in
   0)
      /bin/busybox poweroff -f
   ;;
   6)
      /bin/busybox reboot -f
   ;;
esac
