: ${TMPFS_MOUNT_CONTAINER_OPTS=mode=0775,uid=0,gid=6,nodev,noexec,nosuid,sync}

# int dotmpfs ( mp, name=none, opts=defaults,rw, fstype=tmpfs )
#
#  Mounts a tmpfs at the given mountpoint.
#
dotmpfs() {
   domount_fs "${1:?}" "${2:-none}" "${3:-defaults,rw}" "${4:-tmpfs}"
}

# dotmpfs_mount_container ( mp, container_name=<auto>, size=7m )
#
#  Initializes a mount container at the given position.
#
dotmpfs_mount_container() {
   local mp="${1:?}" name="${2-}"
   [ -n "${name}" ] || name="${mp##*/}fs"

   dodir_clean "${mp}" && \
   dotmpfs "${mp}" "${name}" \
      ${TMPFS_MOUNT_CONTAINER_OPTS:?},size="${3:-7m}" && \
   touch "${mp}/.keep"
}
