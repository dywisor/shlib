: ${DEV_TMPFS_OPTS:=rw,nosuid,relatime,size=10240k,nr_inodes=64012,mode=755}
: ${DEVPTS_OPTS:=rw,nosuid,noexec,relatime,gid=5,mode=620}

: ${INITRAMFS_MDADM_OPTS=--no-degraded}

# int __devfs_donod ( dev, *<mknod arg> )
#
#  Creates a device node if it does not exist.
#
__devfs_donod() {
   [ -e "${1}" ] || mknod "$@"
}

# int __devfs_configure ( **DEVFS_TYPE! )
#
#  Sets DEVFS_TYPE if unset.
#
__devfs_configure() {
   if [ -z "${DEVFS_TYPE-}" ]; then
      if initramfs_use mdev; then
         DEVFS_TYPE=mdev
      else
         DEVFS_TYPE=devtmpfs
      fi
   fi
}

# void devfs_seed()
#
#  Creates essential device nodes in /dev.
#
devfs_seed() {
   irun dodir_clean /dev

   irun __devfs_donod /dev/console c 5 1
   irun __devfs_donod /dev/null    c 1 3
   irun __devfs_donod /dev/ttyS0   c 4 64
   irun __devfs_donod /dev/tty     c 5 0
   irun __devfs_donod /dev/urandom c 1 9
   irun __devfs_donod /dev/random  c 1 8
   irun __devfs_donod /dev/zero    c 1 5
   irun __devfs_donod /dev/kmsg    c 1 11

   irun dosym /proc/self/fd   /dev/fd
   irun dosym /proc/self/fd/0 /dev/stdin
   irun dosym /proc/self/fd/1 /dev/stdout
   irun dosym /proc/self/fd/2 /dev/stderr
}

# void devfs_mount (
#    **DEVFS_TYPE,
#    **DEV_TMPFS_OPTS,
#    **MDEV_SEQ=y,
#    **DEVPTS_OPTS,
#    **F_WAITFOR_DISK_DEV_SCAN!
# )
#
#  Mounts a device filesystem at /dev.
#
devfs_mount() {
   __devfs_configure
   irun dodir_clean /dev

   case "${DEVFS_TYPE}" in
      static)
         true
      ;;
      devtmpfs)
         imount -t devtmpfs -o ${DEV_TMPFS_OPTS:?} devtmpfs /dev
      ;;
      mdev)
         imount -t tmpfs -o ${DEV_TMPFS_OPTS:?} mdev /dev
         devfs_seed

         [ -e /etc/mdev.conf       ] || inonfatal touch /etc/mdev.conf
         [ "${MDEV_SEQ:-y}" != "y" ] || irun      touch /dev/mdev.seq

         if [ ! -e /sbin/mdev ]; then
            [ -e /bin/busybox ] || function_die "mdev needs /bin/busybox"
            irun dodir_clean /sbin
            irun ln -s /bin/busybox /sbin/mdev
         fi

         inonfatal dofile /proc/sys/kernel/hotplug /sbin/mdev "n"
         irun mdev -s

         : ${F_WAITFOR_DISK_DEV_SCAN=mdev -s}

         # this should be a directory
         if [ -c /dev/pktcdvd ]; then
            inonfatal rm /dev/pktcdvd && \
            inonfatal mkdir /dev/pktcdvd && \
            inonfatal mknod /dev/pktcdvd/control c 10 61
         fi
      ;;
      *)
         function_die "devfs type ${DEVFS_TYPE} is not supported."
      ;;
   esac
   if inonfatal dodir_clean /dev/pts; then
      imount -t devpts -o ${DEVPTS_OPTS:?} devpts /dev/pts
   fi
   inonfatal dodir_clean /dev/shm
   inonfatal call_if_defined eval_scriptinfo
   return 0
}

# int devfs_lvm()
#
#  Scans for lvm volume groups.
#
#  !!! only suitable for temporary /
#
devfs_lvm() {
   if [ -d /etc/lvm/cache ]; then
      inonfatal rm -r -- /etc/lvm/cache
   fi
   lvm vgchange -a -y
}

# int devfs_mdadm ( [md_device] )
#
#  Scans for all software raid arrays (or a specific one).
#
devfs_mdadm() {
   if [ -n "$*" ]; then
      mdadm --assemble ${INITRAMFS_MDADM_OPTS-} "$@"
   else
      mdadm --assemble ${INITRAMFS_MDADM_OPTS-} --scan
   fi
}
