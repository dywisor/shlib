#@section header
# int liram_populate_layout_default()
#
# ----------------------------------------------------------------------------
#
# Populates the following directories in %NEWROOT:
#
# / (mandatory)
# * As tmpfs using the 'rootfs' tarball
#
# /etc (optional)
# * Replaces the /etc directory from the rootfs tarball with the contents of
#   the 'etc' tarball if LIRAM_ETC_INCREMENTAL is not set to 'y', else
#   simply extracts the tarball into /etc/.
#
# !!! Make sure to set LIRAM_ETC_INCREMENTAL=y if /etc is a subtree (tmpfs).
#     liram_setup_subtrees() will do this automatically.
#
# /var (optional)
# * Extracts the 'var' tarball into /var
#
# /var/log (optional)
# * Extracts the 'log' tarball into /var/log
#
# /usr (optional)
# * Extracts the 'usr' tarball into /usr
# * Mounts the 'usr' squashfs file at /usr after copying it into %NEWROOT
#
# /home (optional)
# * Extracts the 'home' tarball into /home or $NEWROOT_HOME_DIR (if set).
#
# /sh (optional)
# * Extracts the 'scripts' tarball into /sh
#
#
# Tarballs take higher precedence, so if both usr.sfs and usr.tgz are
# available, then the usr.tgz file will be used.
#
# Calls liram_setup_subtrees() after unpacking the rootfs and
# newroot_setup_all() after populating newroot.
# Also exports boot-time variables such as LIRAM_DISK to NEWROOT as file.
#
# Note: "optional" means that it is okay if the tarball does not exist,
#       it doesn't mean that it's optional whether it can be extracted
#       without errors or not.
#
#
# ----------------------------------------------------------------------------
#

#@section functions
# int liram_populate_layout_default()
#
liram_populate_layout_default() {
   if [ "${LIRAM_LAYOUT:?}" = "default" ]; then
      liram_info "default layout"
      # restrict these variables to what was known
      # at the time writing this module
      local \
         TARBALL_SCAN_NAMES="rootfs var usr etc home scripts log" \
         SFS_SCAN_NAMES="usr home etc scripts"
   else
      liram_info "default layout (inherited)"
   fi

   local usr_sfs="" home_sfs="" etc_sfs="" scripts_sfs=""

   # scan files
   irun liram_scan_files

   # unpack the rootfs tarball
   liram_log_tarball_unpacking "rootfs"
   irun liram_unpack_default rootfs

   # early setup (liram subtrees)
   inonfatal liram_setup_subtrees

   # unpack etc tarball or else import etc sfs (optional)
   if liram_unpack_etc; then
      true
   elif liram_sfs_container_import etc; then
      etc_sfs="${v0}"
      liram_log_sfs_imported "etc"
   else
      liram_log_nothing_found "etc"
   fi

   # unpack var tarball (optional)
   if liram_unpack_optional var; then
      liram_log_tarball_unpacked "var"
   else
      liram_log_nothing_found "var"
   fi

   # unpack log tarball (optional)
   if liram_unpack_optional log; then
      liram_log_tarball_unpacked "log"
   else
      liram_log_nothing_found "log"
   fi

   # unpack usr tarball or else import usr sfs (optional)
   if liram_get_tarball usr; then
      liram_log_tarball_unpacking "usr"
      liram_unpack_default usr "${v0:?}"
   elif liram_sfs_container_import usr; then
      usr_sfs="${v0}"
      liram_log_sfs_imported "usr"
   else
      liram_log_nothing_found "usr"
   fi

   # set NEWROOT_HOME_DIR
   newroot_detect_home_dir
   liram_log DEBUG "home directory is ${NEWROOT_HOME_DIR}"

   # unpack home tarball or else import home sfs (optional)
   if liram_get_tarball home; then
      liram_log_tarball_unpacking "home"
      liram_unpack_default home "${v0:?}"
   elif liram_sfs_container_import home; then
      home_sfs="${v0}"
      liram_log_sfs_imported "home"
   else
      liram_log_nothing_found "home"
   fi

   # unpack scripts tarball or else import scripts sfs (optional)
   if liram_get_tarball scripts; then
      liram_log_tarball_unpacking "scripts"
      liram_unpack_default scripts "${v0:?}"
   elif liram_sfs_container_import scripts; then
      scripts_sfs="${v0}"
      liram_log_sfs_imported "scripts"
   else
      liram_log_nothing_found "scripts"
   fi

   # if any sfs file imported:
   if newroot_sfs_container_avail; then
      liram_info \
         "mounting squashfs files:${usr_sfs:+ usr}${home_sfs:+ home}${etc_sfs:+ etc}${scripts_sfs:+ scripts}"

      # finalize sfs container (mount readonly, ...)
      irun newroot_sfs_container_finalize

      # mount usr sfs if imported
      [ -z "${usr_sfs-}" ] || irun newroot_sfs_container_mount usr /usr

      # mount home sfs if imported
      if [ -n "${home_sfs-}" ]; then
         if [ -n "${LIRAM_HOME_TMPFS_SIZE-}" ]; then
            # as union<tmpfs,sfs>
            irun newroot_sfs_container_mount_writable \
               home "${NEWROOT_HOME_DIR?}" "${LIRAM_HOME_TMPFS_SIZE}"
         else
            # users will curse you
            irun newroot_sfs_container_mount home "${NEWROOT_HOME_DIR?}"
         fi
      fi

      # mount etc sfs if imported
      if [ -n "${etc_sfs-}" ]; then
         if [ -n "${LIRAM_ETC_TMPFS_SIZE-}" ]; then
            # as union<tmpfs,sfs>
            irun newroot_sfs_container_mount_writable \
               etc /etc "${LIRAM_ETC_TMPFS_SIZE}"
         else
            # readonly /etc requires some changes in the rootfs
            irun newroot_sfs_container_mount etc /etc
         fi
      fi

      # mount scripts sfs if imported
      [ -z "${scripts_sfs-}" ] || \
         irun newroot_sfs_container_mount scripts /scripts
   fi

   # final setup (dirs and mounts)
   inonfatal newroot_setup_all

   # write liram env
   inonfatal liram_write_env

   # don't pass the last inonfatal return value
   return 0
}
