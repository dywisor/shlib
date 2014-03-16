#@section header
# int liram_populate_layout_squashed_ro_rootfs()
#
# ----------------------------------------------------------------------------
#
# Populates the following directories in %NEWROOT:
#
# / (mandatory)
# * As tmpfs using the 'rootfs' tarball
#
# /squashed-rootfs (mandatory, readonly)
# * Mounts the 'squashed-rootfs' squashfs file at /squashed-rootfs
#   after copying it into %NEWROOT
#
# /etc (mandatory) [non-hybrid only]
# * As tmpfs using the 'etc' tarball
#
# /var (mandatory) [non-hybrid only]
# * As tmpfs using the 'var' tarball
#
# /kernel-modules (optional)
# * As tmpfs using the 'kmod' tarball
# * or as squashfs using the 'kmod' sfs file
#
# /sh (optional)
# * As tmpfs using the 'scripts' tarball
#
# ----------------------------------------------------------------------------
#

#@section functions
# int liram_populate_layout_squashed_ro_rootfs ( **NEWROOT_HOME_DIR! )
#
liram_populate_layout_squashed_ro_rootfs() {
   local p
   local kmod_sfs=
   local sroot_sfs=

   local is_hybrid="${LIRAM_LAYOUT_HYBRID:-n}"

   # restrict these variables to what was known
   # at the time writing this module
   local TARBALL_SCAN_NAMES="rootfs kmod scripts var etc"
   local SFS_SCAN_NAMES="squashed-rootfs kmod"

   if [ "${LIRAM_LAYOUT:?}" = "squashed_ro_rootfs" ]; then
      liram_info "${LIRAM_LAYOUT}"
   else
      liram_info "squashed_ro_rootfs layout (inherited)"
   fi

   # scan files
   irun liram_scan_files

   # unpack the rootfs tarball
   liram_log_tarball_unpacking "rootfs"
   irun liram_unpack_default rootfs

   # early setup (liram subtrees)
   inonfatal liram_setup_subtrees

   # /squashed-rootfs #1
   irun liram_sfs_container_import squashed-rootfs
   sroot_sfs="${v0:?}"
   liram_log_sfs_imported "squashed-rootfs"

   if [ "${is_hybrid}" = "n" ]; then
      # unpack etc, var
      for p in etc var; do
         irun liram_unpack_default "${p}"
      done
   fi

   # /kernel-modules #1
   if liram_get_tarball kmod; then
      liram_log_tarball_unpacking "kmod"
      newroot_unpack_tarball "${v0:?}" "/kernel-modules"
   elif liram_sfs_container_import kmod; then
      kmod_sfs="${v0:?}"
      liram_log_sfs_imported "kmod"
   else
      liram_log_nothing_found "kmod"
   fi

   # /scripts
   if liram_get_tarball scripts; then
      liram_log_tarball_unpacking "scripts"
      irun liram_unpack_default scripts "${v0:?}"
   else
      liram_log_nothing_found "scripts"
   fi

   # mount squashfs files
   # * /squashed-rootfs (mandatory)
   # * /kernel-modules (optional)
   #
   if newroot_sfs_container_avail; then
      [ -n "${sroot_sfs-}" ] || liram_die "squashed-rootfs?"

      liram_info \
         "mounting squashfs files ${sroot_sfs-}${kmod_sfs:+ }${kmod_sfs-}"

      # finalize sfs container (mount readonly, ...)
      irun newroot_sfs_container_finalize

      if [ -n "${sroot_sfs-}" ]; then
         irun newroot_sfs_container_mount squashed-rootfs /squashed-rootfs
      fi

      if [ -n "${kmod_sfs-}" ]; then
         irun newroot_sfs_container_mount kmod /kernel-modules
      fi
   else
      liram_die "squashfs container is missing."
   fi

   # run pre-setup hook [hybrid mode only]
   if [ "${is_hybrid}" != "n" ]; then
      newroot_setup_run_hook newroot-pre-setup
   fi

   # newroot setup (dirs and mounts)
   inonfatal newroot_setup_all

   # set NEWROOT_HOME_DIR
   newroot_detect_home_dir
   liram_log DEBUG "home directory is ${NEWROOT_HOME_DIR}"

   # write liram env
   inonfatal liram_write_env

   # run post-populate hook [hybrid mode only]
   if [ "${is_hybrid}" != "n" ]; then
      newroot_setup_run_hook liram-post-populate
   fi

   # don't pass the last inonfatal return value
   return 0
}
