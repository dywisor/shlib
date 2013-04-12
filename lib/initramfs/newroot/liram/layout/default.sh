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
# Note: "optional" means that it is okay if the tarball does not exist,
#       it doesn't mean that it's optional whether it can be extracted
#       without errors or not.
#
#
# ----------------------------------------------------------------------------
#
liram_populate_layout_default() {
   if [ "${LIRAM_LAYOUT:?}" = "default" ]; then
      # restrict these variables to what was known
      # at the time writing this module
      local \
         TARBALL_SCAN_NAMES="rootfs var usr etc home scripts log" \
         SFS_SCAN_NAMES="usr home etc scripts"
   fi

   local usr_sfs="" home_sfs="" etc_sfs="" scripts_sfs=""

   irun liram_scan_files

   irun liram_unpack_default rootfs "${v0}"

   if ! liram_unpack_optional etc; then
      liram_sfs_container_import etc && etc_sfs="${v0}"
   fi

   liram_unpack_optional var
   liram_unpack_optional log

   if ! liram_unpack_optional usr; then
      liram_sfs_container_import usr && usr_sfs="${v0}"
   fi

   newroot_detect_home_dir
   ${LOGGER} --level=DEBUG "home directory is ${NEWROOT_HOME_DIR}"

   if ! liram_unpack_optional home; then
      liram_sfs_container_import home && home_sfs="${v0}"
   fi

   if ! liram_unpack_optional scripts; then
      liram_sfs_container_import scripts && scripts_sfs="${v0}"
   fi

   # if any sfs file imported:
   if sfs_container_avail; then

      irun sfs_container_finalize

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
}
