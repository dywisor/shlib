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

# int devfs_set_hotplug_agent ( str="" )
#
#  Sets up %str as hotplug agent.
#
devfs_set_hotplug_agent() {
   if [ -e /proc/sys/kernel/hotplug ]; then
      echo "${1-}" > /proc/sys/kernel/hotplug "${1-}"
   elif [ -x /sbin/sysctl ]; then
      /sbin/sysctl -w kernel.hotplug="${1-}"
   elif [ -x /usr/sbin/sysctl ]; then
      /usr/sbin/sysctl -w kernel.hotplug="${1-}"
   else
      return 0
   fi
}


# int devfs_seed ( devfs=/dev, **AUTODIE=, **AUTODIE_NONFATAL= )
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

      ${AUTODIE_NONFATAL-} dodir_clean \
         "${devfs}/pts" "${devfs}/shm" "${devfs}/mapper"   || true
   else
      fail=1
   fi

   return ${fail}
}

# void devfs__mdev_initvars (
#    devfs=/dev, **X_MDEV!, **BUSYBOX!, **devfs!
# ), raises function_die()
#
#  Initializes some mdev-related vars.
#
devfs__mdev_initvars() {
   : ${X_MDEV:=/sbin/mdev}
   : ${BUSYBOX:=/bin/busybox}

   devfs="${1:-/dev}"

   if [ "${devfs}" != "/dev" ]; then
      function_die "mdev does not support arbitrary mountpoints (${devfs})."
   fi
}

# void devfs__mdev_fixup_exe (
#    **X_MDEV!, **MDEV_ALLOW_SYMLINK_EXE=y
# ), raises function_die()
#
#  Resets %X_MDEV if necessary.
#
#  Creates a symlink /sbin/mdev->/bin/busybox if %X_MDEV needs to be set
#  and MDEV_ALLOW_SYMLINK_EXE is 'y'.
#
devfs__mdev_fixup_exe() {
   : ${X_MDEV:=/sbin/mdev}

   if [ -x "${X_MDEV}" ] || [ -x "${X_MDEV%% *}" ]; then
      true

   elif [ -x "/sbin/mdev" ]; then
      X_MDEV=/sbin/mdev

   elif [ ! -x "${BUSYBOX}" ]; then
      function_die "mdev needs ${BUSYBOX}"

   elif [ "${MDEV_ALLOW_SYMLINK_EXE:-y}" = "y" ]; then
      ${AUTODIE-} dodir_clean /sbin || return
      # ln -s fails if /sbin/mdev exists - this is expected
      ${AUTODIE-} ln -s "${BUSYBOX}" /sbin/mdev || return

      # reset X_MDEV
      X_MDEV=/sbin/mdev
   else
      X_MDEV="${BUSYBOX} mdev"
   fi
}

# int devfs_mount_mdev (
#    devfs=/dev,
#    **F_DOMOUNT_MP=domount3,
#    **DEVTMPFS_OPTS,
#    **X_MDEV!, **BUSYBOX!
# )
#
#  Mounts and initializes a mdev-based /dev.
#
#  Note: mountpoints other than /dev are not supported for DEVFS_TYPE=mdev.
#
devfs_mount_mdev() {
   local devfs
   devfs__mdev_initvars

   if [ "${MDEV_USE_TMPFS:-n}" != "y" ] && fstype_supported devtmpfs; then
      ${F_DOMOUNT_MP:-domount3} "${devfs}" \
         -t devtmpfs -o ${DEVTMPFS_OPTS:?} mdev || return

   else
      ${F_DOMOUNT_MP:-domount3} "${devfs}" \
         -t tmpfs -o ${DEVTMPFS_OPTS:?} mdev || return
   fi

   devfs_seed "${devfs}"
   return 0
}

# int devfs_populate_mdev (
#    devfs=/dev,
#    **AUTODIE=, **AUTODIE_NONFATAL=,
#    **MDEV_SEQ=y, **MDEV_LOG=n,
#    **F_WAITFOR_DISK_DEV_SCAN!,
#    **X_MDEV!, **BUSYBOX!
# ), raises function_die()
#
#  Populates a mdev-based /dev.
#
#  Note: mountpoints other than /dev are not supported for DEVFS_TYPE=mdev.
#
devfs_populate_mdev() {
   local devfs
   devfs__mdev_initvars

   [ -e /etc/mdev.conf ] || ${AUTODIE_NONFATAL-} touch /etc/mdev.conf

   if [ "${MDEV_SEQ:-y}" = "y" ]; then
      ${AUTODIE-} touch "${devfs}/mdev.seq" || return
   fi

   if [ "${MDEV_LOG:-n}" = "y" ]; then
      ${AUTODIE-} touch "${devfs}/mdev.log" || return
   fi

   devfs__mdev_fixup_exe
   ${AUTODIE_NONFATAL-} devfs_set_hotplug_agent "${X_MDEV}"
   ${AUTODIE-} ${X_MDEV} -s || return

   if [ -z "${F_WAITFOR_DISK_DEV_SCAN-}" ]; then
      F_WAITFOR_DISK_DEV_SCAN="${X_MDEV} -s"
   fi

   if [ -e /proc/kcore ]; then
      ${AUTODIE_NONFATAL-} dosym /proc/kcore "${devfs}/core"
   fi

   # this should be a directory
   if [ -c "${devfs}/pktcdvd" ]; then
      ${AUTODIE_NONFATAL-} rm    "${devfs}/pktcdvd" && \
      ${AUTODIE_NONFATAL-} mkdir "${devfs}/pktcdvd" && \
      ${AUTODIE_NONFATAL-} mknod "${devfs}/pktcdvd/control" c 10 61
   fi

   return 0
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

# int devfs_mount_devpts (
#    devfs=/dev,
#    **F_DOMOUNT_MP=domount3, **DEVPTS_OPTS,
#    **AUTODIE_NONFATAL=, **AUTODIE=
# )
#
#  Mounts %devfs/pts.
#
devfs_mount_devpts() {
   if ${AUTODIE_NONFATAL-} dodir_clean "${1:-/dev}/pts"; then
      if ${F_DOMOUNT_MP:-domount3} "${1:-/dev}/pts" \
         -t devpts -o ${DEVPTS_OPTS:?} devpts
      then
         return 0
      else
         return 2
      fi
   fi
   return 1
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
         devfs_mount_mdev "${devfs}" && \
         devfs_populate_mdev "${devfs}" || return
      ;;
      *)
         function_die "devfs type '${DEVFS_TYPE}' is not supported."
      ;;
   esac

   if fstype_supported devpts; then
      devfs_mount_devpts "${devfs}" || fail=1
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
