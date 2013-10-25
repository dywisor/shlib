# int devfs_do_blockdev ( dev, major, minor, **X_MKNOD=mknod )
#
#  Creates a block dev if it doesn't exist.
#
devfs_do_blockdev() {
   [ -b "${1}" ] || ${X_MKNOD:-mknod} b "$@"
}

# int devfs_do_chardev ( dev, major, minor, **X_MKNOD=mknod )
#
#  Creates a char dev if it doesn't exist.
#
devfs_do_chardev() {
   [ -c "${1}" ] || ${X_MKNOD:-mknod} c "$@"
}

# @private int devfs__configure ( **X_MDEV, **BUSYBOX, **DEVFS_TYPE! )
#
#  Sets %DEVFS_TYPE if unset. Returns 0 if successful, else 1.
#
devfs__configure() {
   if [ -z "${DEVFS_TYPE-}" ]; then
      if [ -x "${X_MDEV:?}" ] || [ -x "${BUSYBOX:?}" ]; then
         DEVFS_TYPE=mdev
      elif fstype_supported devtmpfs; then
         DEVFS_TYPE=devtmpfs
      else
         return 1
      fi
   fi
   return 0
}

# int devfs_seed ( devfs=/dev, **AUTODIE= )
#
devfs_seed() {
   local devfs="${1:-/dev}"
   local fail=0

   if ${AUTODIE-} dodir_clean "${devfs}"; then
      ${AUTODIE-} devfs_do_chardev "${devfs}/console" 5 1  || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/null"    1 3  || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/ttyS0"   4 64 || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/tty"     5 0  || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/urandom" 1 9  || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/random"  1 8  || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/zero"    1 5  || fail=2
      ${AUTODIE-} devfs_do_chardev "${devfs}/kmsg"    1 11 || fail=2

      ${AUTODIE-} dosym /proc/self/fd   "${devfs}/fd"      || fail=3
      ${AUTODIE-} dosym /proc/self/fd/0 "${devfs}/stdin"   || fail=3
      ${AUTODIE-} dosym /proc/self/fd/1 "${devfs}/stdout"  || fail=3
      ${AUTODIE-} dosym /proc/self/fd/2 "${devfs}/stderr"  || fail=3
   else
      fail=1
   fi

   return ${fail}
}

# int devfs_mount_mdev (
#    devfs=/dev,
#    **AUTODIE=, **AUTODIE_NONFATAL=,
#    **F_DOMOUNT_MP=domount3,
#    **DEVTMPFS_OPTS,
#    **MDEV_SEQ=y, **MDEV_LOG=n,
#    **F_WAITFOR_DISK_DEV_SCAN!,
#    **X_MDEV!, **BUSYBOX!
# ), raises function_die()
#
#  Mounts and populates a mdev-based /dev.
#
#  Note: mountpoints other than /dev are not supported.
#
devfs_mount_mdev() {
   : ${X_MDEV:=/sbin/mdev}
   : ${BUSYBOX:=/bin/busybox}

   local devfs="${1:-/dev}"

   if [ "${devfs}" != "/dev" ]; then
      function_die "mdev does not support arbitrary mountpoints (${devfs})."

   elif [ "${X_MDEV}" != "${X_MDEV%% *}" ]; then
      # would have to check for newlines etc. too
      function_die "\$X_MDEV must not contain whitespace"

   elif fstype_supported devtmpfs; then
      ${F_DOMOUNT_MP:-domount3} "${devfs}" \
         -t devtmpfs -o ${DEVTMPFS_OPTS:?} mdev || return

   else
      ${F_DOMOUNT_MP:-domount3} "${devfs}" \
         -t tmpfs -o ${DEVTMPFS_OPTS:?} mdev || return
   fi

   devfs_seed "${devfs}"

   [ -e /etc/mdev.conf ] || ${AUTODIE_NONFATAL-} touch /etc/mdev.conf

   if [ "${MDEV_SEQ:-y}" = "y" ]; then
      ${AUTODIE-} touch "${devfs}/mdev.seq" || return
   fi

   if [ "${MDEV_LOG:-n}" = "y" ]; then
      ${AUTODIE-} touch "${devfs}/mdev.log" || return
   fi

   if [ -x "${X_MDEV}" ]; then
      true
   elif [ -x "/sbin/mdev" ]; then
      X_MDEV=/sbin/mdev
   elif [ -x "${BUSYBOX}" ]; then
      ${AUTODIE-} dodir_clean /sbin || return
      # ln -s fails if /sbin/mdev exists - this is expected
      ${AUTODIE-} ln -s "${BUSYBOX}" /sbin/mdev || return

      # reset X_MDEV
      X_MDEV=/sbin/mdev
   else
      function_die "mdev needs ${BUSYBOX}"
   fi

   ${AUTODIE_NONFATAL-} dofile /proc/sys/kernel/hotplug ${X_MDEV} "n"
   ${AUTODIE-} ${X_MDEV} -s || return

   : ${F_WAITFOR_DISK_DEV_SCAN:=${X_MDEV} -s}

   # this should be a directory
   if [ -c "${devfs}/pktcdvd" ]; then
      ${AUTODIE_NONFATAL-} rm    "${devfs}/pktcdvd" && \
      ${AUTODIE_NONFATAL-} mkdir "${devfs}/pktcdvd" && \
      ${AUTODIE_NONFATAL-} mknod "${devfs}/pktcdvd/control" c 10 61
   fi
}


# int devfs_mount_devtmpfs (
#    devfs=/dev, **F_DOMOUNT_MP=domount3, DEVTMPFS_OPTS
# )
#
#  Mounts and populates a devtmpfs-based /dev at %devfs.
#
devfs_mount_devtmpfs() {
   local devfs="${1:-/dev}"
   ${F_DOMOUNT_MP:-domount3} "${devfs}" \
      -t devtmpfs -o ${DEVTMPFS_OPTS:?} devtmpfs || return

   devfs_seed "${devfs}"
}

# int devfs_mount (
#    devfs=/dev,
#    **AUTODIE=, **AUTODIE_NONFATAL=,
#    **F_DOMOUNT_MP=domount3,
#    **DEVFS_TYPE!,
#    **DEVTMPFS_OPTS,
#    **MDEV_SEQ=y, **MDEV_LOG=n,
#    **DEVPTS_OPTS,
#    **F_WAITFOR_DISK_DEV_SCAN!,
#    **X_MDEV!, **BUSYBOX!
# )
#
#  Mounts a device filesystem at %devfs.
#
#  Notes:
#  * F_DOMOUNT_MP has to be a @domount_mp function and is expected to be
#    already wrapped with AUTODIE behavior (if desired)
#  * %devfs has to be /dev (or empty) if mdev is used
#
devfs_mount() {
   local fail=0

   local devfs="${1:-/dev}"
   ${AUTODIE-} devfs__configure       || return
   ${AUTODIE-} dodir_clean "${devfs}" || return

   case "${DEVFS_TYPE}" in
      static)
         true
      ;;
      devtmpfs)
         devfs_mount_devtmpfs || return
      ;;
      mdev)
         devfs_mount_mdev "${devfs}" || return
      ;;
      *)
         function_die "devfs type '${DEVFS_TYPE}' is not supported."
      ;;
   esac

   if fstype_supported devpts; then
      if ${AUTODIE_NONFATAL-} dodir_clean "${devfs}/pts"; then
         ${F_DOMOUNT_MP:-domount3} "${devfs}/pts" \
            -t devpts -o ${DEVPTS_OPTS:?} devpts || fail=1
      fi
   fi

   ${AUTODIE_NONFATAL-} dodir_clean "${devfs}/shm"
   ${AUTODIE_NONFATAL-} call_if_defined eval_scriptinfo

   return ${fail}
}


# int devfs_mdadm ( [md_device], **MDADM_SCAN_OPTS= )
#
#  Scans for all software raid arrays (or a specific one).
#
devfs_mdadm() {
   if [ -n "$*" ]; then
      mdadm --assemble ${MDADM_SCAN_OPTS-} "$@"
   else
      mdadm --assemble ${MDADM_SCAN_OPTS-} --scan
   fi
}
