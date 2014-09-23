#@HEADER
# int liram_populate_layout_stage()
# int liram_populate_layout_squashed_stage()
# int liram_populate_layout_stage3()
# int liram_populate_layout_squashed_stage3()
# int liram_populate_layout_stage4()
# int liram_populate_layout_squashed_stage4()
#
# ----------------------------------------------------------------------------
#
#  Populates %NEWROOT with a stage{,3,4} tarball:
#
# / (mandatory)
# * As tmpfs using the "stage"/"stage3"/"stage4" tarball [stage]
# * As <sfs,tmpfs> union using the "$stage$" squashfs file [squashed_stage]
#
# / (optional)
# * extends the rootfs union with the "$stage$-overlay" squashfs file [squashed_stage]
# * or overwrites / with the contents of the "$stage$-overlay" tarball [ALL]
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
#
# Hooks:
# * liram-rootfs-mounted after creating the rootfs (+ its overlay)
# * liram-subtree-setup  after mounting subtrees
# * liram-post-populate  just before returning
#
#
# NOTE:
#  The name is misleading; this layout was initially written for booting
#  Gentoo stage tarballs, but can handle any rootfs + rootfs-overlay
#  tarball/squashfs setup and is a good choice for "live" systems.
#
# NOTE:
#  kernel modules/firmware can be provided by passing a second initramfs file
#

#@section functions
#
# int liram_populate_layout_stage()
# int liram_populate_layout_squashed_stage()
# int liram_populate_layout_stage3()
# int liram_populate_layout_squashed_stage3()
# int liram_populate_layout_stage4()
# int liram_populate_layout_squashed_stage4()
#
# int liram_layout_stage__populate(<stage name>)
# int liram_layout_squashed_stage__populate(<stage name>)
# int liram_layout_stage__common_populate(<stage name>)
#

liram_populate_layout_stage() {
   liram_layout_stage__populate stage
}

liram_populate_layout_squashed_stage() {
   liram_layout_squashed_stage__populate stage
}

liram_populate_layout_stage3() {
   liram_layout_stage__populate stage3
}

liram_populate_layout_squashed_stage3() {
   liram_layout_squashed_stage__populate stage3
}

liram_populate_layout_stage4() {
   liram_layout_stage__populate stage4
}

liram_populate_layout_squashed_stage4() {
   liram_layout_squashed_stage__populate stage4
}




liram_layout_stage__populate() {
   local v0 TARBALL_SCAN_NAMES SFS_SCAN_NAMES stage_name
   stage_name="${1:?}"

   liram_info "${stage_name} layout"

   TARBALL_SCAN_NAMES="${stage_name} ${stage_name}-overlay"
   SFS_SCAN_NAMES=

   # scan for rootfs file
   irun liram_scan_files

   # unpack stage file
   irun liram_unpack_name "${stage_name}" /

   # stage-overlay
   liram_unpack_optional "${stage_name}-overlay" "" /

   # call common populate function
   irun liram_layout_stage__common_populate "${stage_name}"
}

liram_layout_squashed_stage__populate() {
   local v0 TARBALL_SCAN_NAMES SFS_SCAN_NAMES stage_name
   stage_name="${1:?}"

   # @vars
   # init_sfs_root    : _temporary_ initramfs directory for union base mounts
   #                    * sfs-file-container (./container)
   #                    * stage-sfs-mnt      (./loop/rootfs)
   #                    * memory-mnt         (./mem -- move-mount from /newroot)
   #
   # newroot_sfs_root : final directory for union base mounts
   #
   local init_sfs_root newroot_sfs_root can_cleanup iter mnt_opts
   local stage_sfs overlay_sfs

   liram_info "squashed-${stage_name} layout"
   TARBALL_SCAN_NAMES="${stage_name}-overlay"
   SFS_SCAN_NAMES="${stage_name} ${stage_name}-overlay"

   # scan for stage{,-overlay} files
   irun liram_scan_files

   init_sfs_root="/rootfs_union_root"
   newroot_sfs_root="${NEWROOT:?}/.${init_sfs_root#/}"

   # filecheck
   liram_get_squashfs "${stage_name}" && stage_sfs="${v0:?}" || \
      liram_die "${stage_name}.sfs squashfs file is missing!"

   if liram_get_squashfs "${stage_name}-overlay"; then
      overlay_sfs="${v0:?}"
   else
      overlay_sfs=
   fi

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

   # import stage file
   irun sfs_container_import   "${stage_sfs}" "stage"
   # import overlay file
   if [ -n "${overlay_sfs}" ]; then
      irun sfs_container_import   "${overlay_sfs}" "overlay"
   fi

   # remount sfs container readonly && downsize
   irun sfs_container_finalize

   # mount stage file at <initramfs sfs root>/loop/rootfs
   irun sfs_container_mount    "stage" "${init_sfs_root}/loop/rootfs"
   # mount overlay at <initramfs sfs root>/loop/overlay
   if [ -n "${overlay_sfs}" ]; then
      irun sfs_container_mount "overlay" "${init_sfs_root}/loop/overlay"
   fi

   # mark sfs container as unusable
   SFS_CONTAINER=


   # mount-move should-be-empty %NEWROOT to <initramfs sfs root>/mem
   irun mkdir -p -- "${init_sfs_root}/mem"
   imount --move "${NEWROOT}" "${init_sfs_root}/mem"

   # mount union<mem,loop/rootfs> at %NEWROOT
   mnt_opts="${init_sfs_root}/loop/rootfs=rr"
   [ -z "${overlay_sfs}" ] || \
      mnt_opts="${init_sfs_root}/loop/overlay=rr:${mnt_opts}"
   mnt_opts="br:${init_sfs_root}/mem=rw:${mnt_opts}"

   case "${LIRAM_ROOTFS_TYPE-}" in
      zram)
         mnt_opts="dio,${mnt_opts}"
      ;;
   esac

   # dirperm1: insecure
   mnt_opts="dirperm1,${mnt_opts}"

   imount -t aufs -o "${mnt_opts}" aufs_rootfs "${NEWROOT}"


   # mount-move <initramfs sfs root>/{container,loop/rootfs,mem}
   #  to <newroot sfs root>
   #
   ##hide-bind-mount to avoid UDBA (and add udba=none to aufs mount opts above)
   ##irun mkdir -p -- "${newroot_sfs_root}/HIDE"
   for iter in container loop/rootfs ${overlay_sfs:+loop/overlay} mem; do
      irun mkdir -p -- "${newroot_sfs_root}/${iter}"
      imount --move "${init_sfs_root}/${iter}" "${newroot_sfs_root}/${iter}"
      ##imount --bind "${newroot_sfs_root}/HIDE" "${newroot_sfs_root}/${iter}"
   done

   if [ "${can_cleanup}" = "y" ]; then
      inonfatal rm -r -- "${init_sfs_root}"
   fi

   # ... done !


   # stage-overlay tarball (if no squashfs file found)
   if [ -z "${overlay_sfs}" ]; then
      liram_unpack_optional "${stage_name}-overlay" "" /
   fi

   # call common populate function
   irun liram_layout_stage__common_populate "${stage_name}"
}


liram_layout_stage__common_populate() {
   local v0 TARBALL_SCAN_NAMES SFS_SCAN_NAMES k stage_name
   stage_name="${1:?}"

   liram_info "${stage_name}-common populating"
   TARBALL_SCAN_NAMES="etc kmod firmware scripts"
   SFS_SCAN_NAMES=

   # scan files
   irun liram_scan_files

   # rootfs-mounted hook
   newroot_setup_run_hook liram-rootfs-mounted

   # early setup (liram subtrees)
   inonfatal liram_setup_subtrees
   newroot_setup_run_hook liram-subtree-setup

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
         irun with_globbing_do liram_layout_stage__transfer_files \
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


# @private @recursive int liram_layout_stage__transfer_files ( from, to )
#
liram_layout_stage__transfer_files() {
   local f fname

   if ! mkdir -p -- "${2}/"; then
      liram_log WARN "failed to create dir ${2}"
      return 1
   fi

   for f in "${1}/"*; do
      fname="${f##*/}"

      if [ -f "${f}" ] || [ -h "${f}" ]; then
         if ! cp -a -- "${f}" "${2}/${fname}"; then
            liram_log WARN "failed to copy file ${f}"
            return 2
         fi
      elif [ -d "${f}" ]; then
         if ! \
            liram_layout_stage__transfer_files "${f}" "${2}/${fname}"
         then
            liram_log WARN "failed to copy dir ${f}"
            return 3
         fi
      else
         liram_log WARN "transfer-files: cannot handle ${f}"
      fi
   done
}
