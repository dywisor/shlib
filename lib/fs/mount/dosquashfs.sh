# int dosquashfs ( squashfs_file, mp )
#
#  Mounts a squashfs file at the given mountpoint.
#
dosquashfs() {
   dodir_clean "${2:?}" && \
   do_mount -t squashfs -o ro,loop "${1:?}" "${2:?}"
}
