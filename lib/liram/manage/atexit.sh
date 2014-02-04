#@section module_init_vars
unset -v __LIRAM_MANAGE_ATEXIT


#@section functions

# @extern void atexit_enable(...)
# @extern void atexit_disable(...)
# @extern void atexit_register(...)

# void liram_manage_atexit_register()
#
liram_manage_atexit_register() {
   : ${__LIRAM_MANAGE_ATEXIT:=n}
   atexit_register liram_manage_atexit
}

liram_manage_atexit_enable() {
   __LIRAM_MANAGE_ATEXIT=y
}

liram_manage_atexit_disable() {
   __LIRAM_MANAGE_ATEXIT=n
}


# void liram_manage_atexit()
#
liram_manage_atexit() {
   [ "${__LIRAM_MANAGE_ATEXIT:-y}" = "y" ] || return 0
   __LIRAM_MANAGE_ATEXIT=n

   local LIRAM_MANAGE_PLEASE_DONT_DIE=y

   # cleanup work dir
   if ! liram_manage_success; then
      if [ "${LIRAM_MANAGE_FAIL_CLEAN:-y}" = "y" ]; then
         if \
            [ -n "${LIRAM_DEST_SLOT_WORKDIR-}" ] && \
            [ -d "${LIRAM_DEST_SLOT_WORKDIR-}" ]
         then
            rm -rv -- "${LIRAM_DEST_SLOT_WORKDIR}" || \
               liram_manage_log_error \
                  "failed to remove work dir ${LIRAM_DEST_SLOT_WORKDIR}"
         fi

         if [ -n "${LIRAM_DEST_SLOT-}" ] && [ -d "${LIRAM_DEST_SLOT}" ]; then
            rmdir -v -- "${LIRAM_DEST_SLOT}" || \
               liram_manage_log_warn \
                  "failed to remove slot dir ${LIRAM_DEST_SLOT}"
         fi
      fi

      # <other stuff to do unless script succeeded>
   fi


   # recover LIRAM_BOOT_SLOT if required and possible, then unmount sysdisk
   #
   if [ -n "${LIRAM_DISK_MOUNT_RESTORE-}" ]; then
      liram_manage_fixup_boot_slot
      liram_manage_umount_sysdisk
   fi

   # unmount boot disk
   [ -z "${LIRAM_BOOTDISK_MOUNT_RESTORE-}" ] || liram_manage_umount_boot

   # release locks
   ! liram_manage_have_pack_lock || liram_manage_unlock_pack
}
