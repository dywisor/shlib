# int liram_populate_layout_tv ( **NEWROOT_HOME_DIR! )
#
# ----------------------------------------------------------------------------
#
# This is a strict(er) and less flexible variant of the 'default' layout.
# It's called 'tv' because it's originally written for a home server that
# mainly acts as vdr node.
#
# It populates the following directories in %NEWROOT:
#
# / (mandatory)
# * As tmpfs using the 'rootfs' tarball
#
# /etc (mandatory)
# * Replaces the /etc directory from the rootfs tarball with the contents of
#   the 'etc' tarball if LIRAM_ETC_INCREMENTAL is not set to 'y', else
#   simply extracts the tarball into /etc/.
#
# !!! Make sure to set LIRAM_ETC_INCREMENTAL=y if /etc is a subtree (tmpfs).
#     liram_setup_subtrees() will do this automatically.
#
# /var (mandatory)
# * Extracts the 'var' tarball into /var
#
# /var/log (mandatory)
# * Extracts the 'log' tarball into /var/log
#
# /usr (mandatory)
# * Mounts the 'usr' squashfs file at /usr after copying it into %NEWROOT
#
# /sh (mandatory)
# * Extracts the 'scripts' tarball into /sh
#
# Calls liram_setup_subtrees() after unpacking the rootfs and
# newroot_setup_all() after populating newroot.
#
# Notes:
# * /home should be a symlink to /var/users
#
# ----------------------------------------------------------------------------
#
liram_populate_layout_tv() {
   # the names of all tarballs used by this layout except "rootfs"
   local ADDITIONAL_TARBALL_NAMES="etc var log scripts"

   # setup targets that will be run after populating newroot
   local NEWROOT_SETUP_TARGETS="dirs mountpoints premount tmpdir"

   local name usr_sfs

   if [ "${LIRAM_LAYOUT:?}" = "tv" ]; then
      liram_info "tv layout"
      # set TARBALL_SCAN_NAMES,SFS_SCAN_NAMES (see comment above for details)
      local \
         TARBALL_SCAN_NAMES="rootfs ${ADDITIONAL_TARBALL_NAMES}" \
         SFS_SCAN_NAMES="usr"
   else
      liram_info "tv layout (inherited)"
   fi

   # scan files
   irun liram_scan_files

   # unpack the rootfs tarball
   liram_log_tarball_unpacking "rootfs"
   irun liram_unpack_default rootfs

   # early setup (liram subtrees)
   irun liram_setup_subtrees

   # import usr
   irun liram_sfs_container_import usr
   usr_sfs="${v0:?}"
   liram_log_sfs_imported "usr"

   # double tap / finalize sfs container
   irun newroot_sfs_container_avail
   irun newroot_sfs_container_finalize

   # mount /usr
   liram_info "mounting squashfs: /usr"
   irun newroot_sfs_container_mount usr /usr

   # unpack the remaining tarballs
   for name in ${ADDITIONAL_TARBALL_NAMES?}; do
      if [ "${name}" != "rootfs" ]; then
         liram_log_tarball_unpacking "${name}"
         irun liram_unpack_default "${name}"
      fi
   done

   # set NEWROOT_HOME_DIR and check whether it is /var/users
   #  (not critical, but logs a warning if this test fails)
   if \
      [ -z "${NEWROOT_HOME_DIR-}" ] && \
      newroot_detect_home_dir && \
      [ "${NEWROOT_HOME_DIR}" != "${NEWROOT}/var/users" ]
   then
      liram_log WARN "home directory should be /var/users, not '${NEWROOT_HOME_DIR}'."
   fi

   # final setup (dirs and mounts)
   #  do *not* newroot_setup_all() here - it may change in future
   for name in ${NEWROOT_SETUP_TARGETS?}; do
      irun newroot_setup_${name}
   done
}