#@HEADER
# int liram_populate_layout_stage3()
# int liram_populate_layout_squashed_stage3()
#
# ----------------------------------------------------------------------------
#
#  Populates %NEWROOT with a stage3/4 tarball:
#
# / (mandatory)
# * As tmpfs using the "stage3" tarball [stage3]
# * As <sfs,tmpfs> union using the "stage3" squashfs file [squashed_stage3]
#
# / (optional)
# * overwrites / with the contents of the "stage3-overlay" tarball
#
# /etc (optional)
# * Replaces the /etc directory from the rootfs tarball with the contents of
#   the 'etc' tarball if LIRAM_ETC_INCREMENTAL is not set to 'y', else
#   simply extracts the tarball into /etc/.
#
# /lib/modules (optional)
# * using the "kmod" tarball
# * alternatively, transfers /lib/modules/$(uname -r) from initramfs to
#   newroot if it does not exist in newroot
#
# /lib/firmware (optional)
# * using the "firmware" tarball
# * alternatively, transfers *new* files from <initramfs>/lib/firmware
#   to <newroot>/lib/firmware
#
# /sh (optional)
# * Extracts the 'scripts' tarball to /sh
#
# Calls liram_setup_subtrees() after unpacking the rootfs and
# newroot_setup_all() after populating newroot.
# Also exports boot-time variables such as LIRAM_DISK to NEWROOT as file.
#
# Runs the "liram-post-populate" hook just before returning.
#
#

#@section functions
# int liram_populate_layout_stage3()
# int liram_populate_layout_squashed_stage3()
# int liram_populate_layout__stage3_common()
#

liram_populate_layout_stage3() {
   local v0 TARBALL_SCAN_NAMES SFS_SCAN_NAMES

   liram_info "stage3 layout"

   TARBALL_SCAN_NAMES="stage3"
   SFS_SCAN_NAMES=

   # scan for rootfs file
   irun liram_scan_files

   # unpack stage3
   irun liram_unpack_name stage3 /

   # call common populate function
   irun liram_populate_layout__stage3_common
}

liram_populate_layout_squashed_stage3() {
   local v0 TARBALL_SCAN_NAMES SFS_SCAN_NAMES
   # @vars
   # init_sfs_root    : _temporary_ initramfs directory for union base mounts
   #                    * sfs-file-container (./container)
   #                    * sfs-loop-mnt       (./loop)
   #                    * memory-mnt         (./mem -- move-mount from /newroot)
   #
   # newroot_sfs_root : final directory for union base mounts
   #
   local sfs_file init_sfs_root newroot_sfs_root can_cleanup iter

   liram_info "squashed-stage3 layout"
   TARBALL_SCAN_NAMES=
   SFS_SCAN_NAMES="stage3"

   # scan for rootfs file
   irun liram_scan_files

   init_sfs_root="/rootfs_union_root"
   newroot_sfs_root="${NEWROOT:?}/.${init_sfs_root#./}"

   # filecheck
   liram_get_squashfs stage3 && sfs_file="${v0:?}" || \
      liram_die "stage3.sfs squashfs file is missing!"

   # sanity check
   can_cleanup=y
   if [ -d "${init_sfs_root}" ]; then
      if ! rmdir -- "${init_sfs_root}"; then
         can_cleanup=n
      else
         liram_log_warn "unclean initramfs sfs root"
      fi
   elif [ -e "${init_sfs_root}" ] || [ -h "${init_sfs_root}" ]; then
      liram_die "union root ${init_sfs_root} exists, but is not a dir."
   fi

   # init sfs container
   irun sfs_container_init     "${init_sfs_root}/container"
   # import stage file ("soft-"renaming stage3->stage)
   irun sfs_container_import   "${sfs_file}" "stage"
   # remount sfs container readonly && downsize
   irun sfs_container_finalize
   # mount stage file at <initramfs sfs root>/loop
   irun sfs_container_mount    "stage" "${init_sfs_root}/loop"
   # mark sfs container as unusable
   SFS_CONTAINER=

   # mount-move should-be-empty %NEWROOT to <initramfs sfs root>/mem
   irun mkdir -p -- "${init_sfs_root}/mem"
   imount --move "${NEWROOT}" "${init_sfs_root}/mem"

   # mount union<mem,loop> at %NEWROOT
   imount -t aufs \
      -o "br:${init_sfs_root}/mem=rw:${init_sfs_root}/loop=rr" \
      aufs_rootfs "${NEWROOT}"

## or
##   irun aufs_union "${NEWROOT}" \
##      "${init_sfs_root}/mem" \
##      "${init_sfs_root}/loop" \
##      "" \
##      "aufs_rootfs"

   # mount-move <initramfs sfs root>/{container,loop,mem} to <newroot sfs root>
   for iter in container loop mem; do
      irun mkdir -p -- "${newroot_sfs_root}/${iter}"
      imount --move "${init_sfs_root}/${iter}" "${newroot_sfs_root}/${iter}"
   done

   if [ "${can_cleanup}" = "y" ]; then
      inonfatal rm -r -- "${init_sfs_root}"
   fi

   # ... done !


   # call common populate function
   irun liram_populate_layout__stage3_common
}



liram_populate_layout__stage3_common() {
   local v0 TARBALL_SCAN_NAMES SFS_SCAN_NAMES k

   liram_info "stage3-common populating"
   TARBALL_SCAN_NAMES="stage3-overlay etc kmod firmware scripts"
   SFS_SCAN_NAMES=

   # scan files
   irun liram_scan_files

   # stage3-overlay
   liram_unpack_optional stage3-overlay "" /

   # early setup (liram subtrees)
   inonfatal liram_setup_subtrees

   # unpack remaining tarballs
   liram_unpack_etc || true
   liram_unpack_optional scripts "" /sh

   if liram_get_tarball kmod; then
      liram_log_tarball_unpacking kmod
      irun newroot_unpack_tarball "${v0:?}" /lib/modules
      liram_log_tarball_unpacked kmod

   else
      liram_log_nothing_found kmod

      k="$(uname -r)"
      if [ -z "${k}" ]; then
         true
      elif \
         [ -e "${NEWROOT}/lib/modules/${k}" ] || \
         [ -h "${NEWROOT}/lib/modules/${k}" ]
      then
         liram_info \
            "not transferring kernel modules - ${k} exists in newroot"

      elif [ -d "/lib/modules/${k}/" ]; then
         liram_info \
            "transferring kernel modules for ${k} to newroot"
         irun cp -a -- "/lib/modules/${k}/" "${NEWROOT}/lib/modules/${k}/"

      else
         liram_info "no kernel modules found for ${k} in initramfs"
      fi
   fi

   if liram_get_tarball firmware; then
      liram_log_tarball_unpacking firmware
      irun newroot_unpack_tarball "${v0:?}" /lib/firmware
      liram_log_tarball_unpacked firmware

   else
      liram_log_nothing_found firmware

      if [ -d /lib/firmware/ ]; then
         liram_info \
            "transferring firmware files from initramfs to newroot"
         irun with_globbing_do liram_layout_stage3__transfer_files \
            /lib/firmware "${NEWROOT}/lib/firmware"
      fi
   fi


   # final setup (dirs and mounts)
   inonfatal newroot_setup_all

   # write liram env
   inonfatal liram_write_env

   # run post-populate hook
   newroot_setup_run_hook liram-post-populate

   # don't pass the last inonfatal return value
   return 0
}


# @private @recursive int liram_layout_stage3__transfer_files ( from, to )
#
liram_layout_stage3__transfer_files() {
   local f fname

   inonfatal mkdir -p -- "${2}/" || return

   for f in "${1}/"*; do
      fname="${f##*/}"

      if [ -f "${f}" ] || [ -h "${f}" ]; then
         inonfatal cp -a -- "${f}" "${2}/${fname}" || return
      elif [ -d "${f}" ]; then
         inonfatal liram_layout_stage3__transfer_files \
            "${f}" "${2}/${fname}" || return
      else
         liram_log WARN "transfer-files: cannot handle ${f}"
      fi
   done
}
