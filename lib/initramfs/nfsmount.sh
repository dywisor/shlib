#@section functions

# int initramfs_mount_nfs_nonfatal ( mp, nfs_uri, opts="soft,nolock,ro" )
#
initramfs_mount_nfs_nonfatal() {
   dodir_clean "${1:?}" && \
   do_mount -t nfs -o ${3:-soft,nolock,ro} "${2:?}" "${1:?}"
}

# void initramfs_mount_nfs (...)
#
#  Calls initramfs_mount_nfs_nonfatal(...) and dies on non-zero return.
#
initramfs_mount_nfs() {
   irun initramfs_mount_nfs_nonfatal "$@"
}
