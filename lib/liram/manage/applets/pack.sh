#@section functions

# void liram_manage_merge_slot_workdir (
#    **LIRAM_DEST_SLOT, **LIRAM_DEST_SLOT_WORKDIR
# )
liram_manage_merge_slot_workdir() {
   local restore_noglob=
   local v_opt
   __quiet__ || v_opt="-v"

   if ! check_globbing_enabled; then
      restore_noglob=y
      set +f
   fi

   liram_manage_log_info "Moving image files to slot ${LIRAM_DEST_SLOT_NAME}"
   liram_manage_autodie \
      mv ${v_opt} -t "${LIRAM_DEST_SLOT}" -- "${LIRAM_DEST_SLOT_WORKDIR}/"?*

   liram_manage_log_info "Removing work dir"
   liram_manage_autodie rm -f ${v_opt} -- "${LIRAM_DEST_SLOT_WORKDIR}/.keep"
   liram_manage_autodie rmdir ${v_opt} -- "${LIRAM_DEST_SLOT_WORKDIR}"

   [ -z "${restore_noglob}" ] || set -f
}



# @private int liram_manage_link_core_images__hardlink (
#    **LIRAM_DEST_SLOT, **LIRAM_CORE_IMAGE_DIR, **LIRAM_CORE_IMAGE_RELPATH
# ), raises liram_manage_die()
#
liram_manage_link_core_images__hardlink() {
   local fspath fname name

   liram_manage_log_info "Adding core images"

   for fspath in "${LIRAM_CORE_IMAGE_DIR}/"*.*; do
      fname="${fspath##*/}"
      name="${fname%%.*}"
      : ${name:=${fname}}

      set -- "${LIRAM_DEST_SLOT}/${name}."*

      # -n ${1} always true here
      if [ -n "${1-}" ] && [ "${1}" = "${LIRAM_DEST_SLOT}/${name}.*" ]; then
         # add file
         liram_manage_log_info "Adding core image ${fname} (as hardlink)"
         liram_manage_autodie ln -T -- \
            "${fspath}" "${LIRAM_DEST_SLOT}/${fname}" || return
      fi
      # else file exists in LIRAM_DEST_SLOT
      #  (possibly with a different file ext)
   done
}

# void liram_manage_link_core_images (
#    **LIRAM_DEST_SLOT, **LIRAM_CORE_IMAGE_DIR, **LIRAM_CORE_IMAGE_RELPATH
# ), raises liram_manage_die()
#
liram_manage_link_core_images() {
   if [ -z "${LIRAM_CORE_IMAGE_DIR-}" ]; then
      liram_manage_log_debug "no core image dir configured."
      return 0

   elif [ ! -d "${LIRAM_CORE_IMAGE_DIR}" ]; then
      liram_manage_die \
         "core image dir ${LIRAM_CORE_IMAGE_DIR} does not exist."

   elif [ "${LIRAM_HARDLINK_CORE:-y}" = "y" ]; then
      liram_manage_autodie \
         with_globbing_do liram_manage_link_core_images__really "$@"

   else
      liram_manage_die \
         "liram_manage_link_core_images(): only hardlinks are supported."
   fi
}


liram_manage_pack_main() {
   liram_manage_success n

   if ! liram_manage_have_pack_script; then
      liram_manage_die "pack applet needs a valid \$LIRAM_MANAGE_PACK_SCRIPT."
      return ${?}
   elif [ -z "${PACK_TARGETS-}" ]; then
      liram_manage_die "pack: no targets given."
      return ${?}
   elif ! liram_manage_check_sysdisk_vars; then
      return 2
   elif [ ${UID} -ne 0 ]; then
      liram_manage_die "pack applet must be run as root."
      return ${?}
   elif ! liram_manage_create_lockdir; then
      return 2
   fi

   # atexit behavior is required now
   liram_manage_atexit_enable

   # acquire the pack lock
   liram_manage_lock_pack || return

   # mount the sysdisk
   liram_manage_mount_sysdisk || return

   # get a slot
   liram_manage_get_slot || return

   # call the pack script
   liram_manage_autodie \
      liram_manage_call_pack_script ${PACK_TARGETS-} || return

   # transfer files from work dir to dest slot / remove work dir
   liram_manage_merge_slot_workdir || return

   # import core images (if any)
   liram_manage_link_core_images || return

   LIRAM_DEST_SLOT_SUCCESS=y

   # update the boot slot
   liram_manage_update_boot_slot "${LIRAM_DEST_SLOT_NAME}" || return

   # release the pack lock
   liram_manage_unlock_pack || return

   # done
   liram_manage_success 0
   liram_manage_log_info \
      "Successfully created new slot ${LIRAM_DEST_SLOT_NAME}"
}
