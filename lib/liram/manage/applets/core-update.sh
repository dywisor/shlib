#@section functions

liram_manage_update_core_main() {
   liram_manage_success n

   if ! liram_manage_have_update_core_script; then
      liram_manage_die \
         "update-core applet needs a valid \$LIRAM_MANAGE_X_UPDATE_CORE script."
      return ${?}
   elif ! liram_manage_check_sysdisk_vars; then
      return 2
   elif [ -z "${LIRAM_CORE_IMAGE_DIR-}" ]; then
      liram_manage_die "\$LIRAM_CORE_IMAGE_DIR is not set."
   elif [ ${UID} -ne 0 ]; then
      liram_manage_die "update-core applet must be run as root."
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

   # call LIRAM_MANAGE_X_UPDATE_CORE
   liram_manage_autodie dodir_clean "${LIRAM_CORE_IMAGE_DIR}" || return
   liram_manage_autodie ${LIRAM_MANAGE_X_UPDATE_CORE} \
      "${LIRAM_CORE_IMAGE_DIR%/}/" || return

   # unmount the sysdisk
   liram_manage_unmount_sysdisk || return

   # release the pack lock
   liram_manage_unlock_pack || return

   # done
   liram_manage_success 0
   liram_manage_log_info "Core images have been updated."
   liram_manage_log_info \
      "To make use of them, you need to create a new slot with --pack."
}
