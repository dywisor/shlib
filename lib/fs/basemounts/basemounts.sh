# int basemounts_mount (
#    root=/, **DEVFS_TYPE, **PROCFS_OPTS, **SYSFS_OPTS,
#    **F_DOMOUNT_MP=domount3, **F_DOMOUNT_PROC=**F_DOMOUNT_MP,
#    **AUTODIE=, **AUTODIE_NONFATAL=
# )
#
#  Creates a minimal static /dev and mounts all basemounts afterwards,
#  namely /proc, /sys, /dev and /dev/pts (in that order).
#
basemounts_mount() {
   local ROOT="${1:-/}"
   local f_mount_proc="${F_DOMOUNT_PROC:-${F_DOMOUNT_MP:-domount3}}"
   [ -n "${MOUNTOPTS_APPEND-}" ] || local MOUNTOPTS_APPEND="-n"

   # static /dev
   devfs_seed "${ROOT}dev"

   # make dirs
   ${AUTODIE-} dodir_clean "${ROOT}proc" "${ROOT}sys" || return

   # /proc
   ${f_mount_proc} "${ROOT}proc" -t proc -o ${PROCFS_OPTS:?} proc

   # set up /etc/mtab
   ${AUTODIE_NONFATAL-} ln -sf "${ROOT}proc/self/mounts" "${ROOT}etc/mtab"

   # /sys
   ${F_DOMOUNT_MP:-domount3} "${ROOT}sys" -t sysfs -o ${SYSFS_OPTS:?} sysfs

   # /dev and /dev/pts
   devfs_mount "${ROOT}dev"
}
