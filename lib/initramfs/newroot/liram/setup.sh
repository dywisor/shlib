#@section functions_export

# @extern int  newroot_setup_dirs        ( *file=<default> )
# @extern int  newroot_setup_mountpoints ( fstab_file=<default> )
# @extern int  newroot_setup_premount    ( file=<default>, **CMDLINE_FSCK )
# @extern int newroot_setup_tmpdir       ( file=<default> )
# @extern void newroot_setup_all()

#@section module_init
: ${NEWROOT_CONFIG_DIR?}


#@section functions

# int liram_setup_subtrees ( *file=<detect>, **NEWROOT, **NEWROOT_CONFIG_DIR )
#
#  Reads subtree configuration from file(s) and mounts the subtrees
#  accordingly.
#
#  Returns on success and 40 if any of the given files did not exist.
#  Also returns 0 if no file was specified and the default did not exist.
#
#  This should be called as early as possible, usually after unpacking
#  the rootfs tarball (or mounting the rootfs disk).
#
liram_setup_subtrees() {
   if [ -z "${1-}" ]; then
      set -- "${NEWROOT?}/${NEWROOT_CONFIG_DIR#/}/liram-subtree"
      [ -f "${1}" ] || return 0
   fi

   ## file format: <mountpoint> <size_m> [<name> [<mount_opts>]]
   ## Surprisingly, this is also what liram_mount_subtree() expects.
   ##
   F_ITER=liram_mount_subtree \
   F_ITER_ON_ERROR=return \
   ITER_UNPACK_ITEM=y ITER_SKIP_COMMENT=y ITER_SKIP_EMPTY=y \
   file_iterator "$@"
}
