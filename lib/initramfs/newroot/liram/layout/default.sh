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
# *** subtrees are not implemented ***
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
# Tarballs take higher precedence, so if there's a a usr.sfs and a usr.tgz
# available, the usr.tgz file will be used.
#
# Calls liram_setup_subtrees() after unpacking the rootfs and
# newroot_setup_all() after populating newroot.
#
# Note: "optional" means that it is okay if the tarball does not exist,
#       it doesn't mean that it's optional whether it can be extracted
#       without errors or not.
#
#
# ----------------------------------------------------------------------------
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

   irun liram_scan_files

   liram_log_tarball_unpacking "rootfs"
   irun liram_unpack_default rootfs

   inonfatal liram_setup_subtrees

   if liram_get_tarball etc; then
      liram_log_tarball_unpacking "etc"
      irun newroot_replace_etc "${v0:?}"
   elif liram_sfs_container_import etc; then
      etc_sfs="${v0}"
      liram_log_sfs_imported "etc"
   else
      liram_log_nothing_found "etc"
   fi

   if liram_unpack_optional var; then
      liram_log_tarball_unpacked "var"
   else
      liram_log_nothing_found "var"
   fi

   if liram_unpack_optional log; then
      liram_log_tarball_unpacked "log"
   else
      liram_log_nothing_found "log"
   fi

   if liram_get_tarball usr; then
      liram_log_tarball_unpacking "usr"
      liram_unpack_default usr "${v0:?}"
   elif liram_sfs_container_import usr; then
      usr_sfs="${v0}"
      liram_log_sfs_imported "usr"
   else
      liram_log_nothing_found "usr"
   fi

   newroot_detect_home_dir
   liram_log DEBUG "home directory is ${NEWROOT_HOME_DIR}"

   if liram_get_tarball home; then
      liram_log_tarball_unpacking "home"
      liram_unpack_default home "${v0:?}"
   elif liram_sfs_container_import home; then
      home_sfs="${v0}"
      liram_log_sfs_imported "home"
   else
      liram_log_nothing_found "home"
   fi

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

      irun newroot_sfs_container_finalize

      [ -z "${usr_sfs-}" ] || irun newroot_sfs_container_mount usr /usr

      if [ -n "${home_sfs-}" ]; then
         if [ -n "${LIRAM_HOME_TMPFS_SIZE-}" ]; then
            irun newroot_sfs_container_mount_writable \
               home "${NEWROOT_HOME_DIR?}" "${LIRAM_HOME_TMPFS_SIZE}"
         else
            # users will curse you
            irun newroot_sfs_container_mount home "${NEWROOT_HOME_DIR?}"
         fi
      fi

      if [ -n "${etc_sfs-}" ]; then
         if [ -n "${LIRAM_ETC_TMPFS_SIZE-}" ]; then
            irun newroot_sfs_container_mount_writable \
               etc /etc "${LIRAM_ETC_TMPFS_SIZE}"
         else
            # readonly /etc requires some changes in the rootfs
            irun newroot_sfs_container_mount etc /etc
         fi
      fi

      [ -z "${scripts_sfs-}" ] || \
         irun newroot_sfs_container_mount scripts /scripts
   fi

   inonfatal newroot_setup_all
}
