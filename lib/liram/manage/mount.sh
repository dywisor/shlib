#@section symdef

# @symdef function_ref LIRAM_MOUNT_STATE_RESTORE
#
#  Reference to a function that is capable of restoring the previous state
#  of a mount point.
#
#  Either "liram_manage_keep_mount", "remount_ro" or "do_umount",
#  which all accept a mountpoint as arg.
#

# @section funcdef

# @funcdef liram_manage_locate_disk <disk> void liram_manage_get_<disk> (
#    **LIRAM_<name>, **LIRAM_<name>_DEV?!
# )
#
#  Resolves the device name of <disk> and stores it in LIRAM_<name>_DEV.
#
#  Doesn't need to be called manually, see @liram_manage_mount below.
#

# @funcdef liram_manage_mount <disk> void liram_manage_mount_<disk> (
#    **LIRAM_<name>_DEV!, **LIRAM_<name>_MP,
#    **LIRAM_<name>_FSTYPE=auto,
#    **LIRAM_<name>_MOUNT_RESTORE?!
# ) [LIRAM_<name>], raises liram_manage_die()
#
#  Mounts <disk> writable and remembers how to restore
#  the previous mount state. Dies on error.
#
#  Calls liram_manage_get_<disk>() if **LIRAM_<name>_DEV is not set.
#

# @funcdef liram_manage_umount <disk> void liram_manage_umount_<disk> (
#    **LIRAM_<name>_MP, **LIRAM_<name>_MOUNT_RESTORE?!
# ) [LIRAM_<name>], raises liram_manage_die()
#
#  Restores the state of a previously(!) mounted disk.
#


#@section functions

# void liram_manage_keep_mount ( mp )
#
#  Dummy function for @LIRAM_MOUNT_STATE_RESTORE.
#
#  Note that this function is *NOT* called in @liram_manage_umount functions.
#  It may be used in custom scripts, though.
#
liram_manage_keep_mount() {
   return 0
}


# @private void liram_manage__locate_disk ( disk_identifier, **DISK_DEV! )
#
liram_manage__locate_disk() {
   liram_manage_log_debug "trying to resolve device '${1}'"
   get_disk "${1:?}" || liram_manage_die "cannot resolve device name of ${1}"
}


# @private void liram_manage__mount_disk_writable (
#    prev_state, dev, mp, fstype=auto, opts="noatime,rw", **v0!
# ), raises liram_manage_die()
#
#  (Re-)mounts a device %dev writable at %mp and stores the previous mount
#  state in %v0. Dies on error.
#
#  Creates a %mp/.keep file before trying to remount.
#
liram_manage__mount_disk_writable() {
   v0=
   local prev_state="${1-}"
   local dev="${2:?}"
   local mp="${3:?}"
   local fstype="${4:-auto}"
   local opts="${5:-noatime,rw}"


   if disk_mounted "${dev}" "${mp}"; then
      if liram_manage_check_dir_writable "${mp}"; then
         v0="${prev_state:-liram_manage_keep_mount}"

      elif [ -n "${prev_state}" ]; then
         liram_manage_die \
            "cannot remount_rw ${mp}: \$prev_state is set." || return

      else
         liram_manage_autodie remount_rw "${mp}" || return
         v0=remount_ro
      fi

   elif disk_mounted "${dev}"; then
      liram_manage_die \
         "${dev} is already mounted (but not at ${mp})." || return

   elif [ -n "${prev_state}" ]; then
      liram_manage_die \
         "cannot mount ${mp} writable: \$prev_state is set." || return

   else
      liram_manage_autodie dodir_minimal "${mp}" || return
      liram_manage_autodie do_mount \
         -t "${fstype}" -o "${opts}" "${dev}" "${mp}" || return
      v0=do_umount
   fi
   #@VARCHECK v0
}

# @private liram_manage__restore_mount_state ( mount_state, mp ), raises die()
#
liram_manage__restore_mount_state() {
   case "${1?}" in
      '')
         liram_manage_log_warn "restore-mount: no mount state set for ${2}"
         return 0
      ;;
      'liram_manage_keep_mount')
         liram_manage_log_info "restore-mount: keeping ${2} as-is."
         return 0
      ;;
      'remount_ro')
         liram_manage_log_info "restore-mount: remounting ${2} readonly"
         liram_manage_autodie "${1}" "${2}"
         return ${?}
      ;;
      'do_umount')
         liram_manage_log_info "restore-mount: unmounting ${2}"
         liram_manage_autodie "${1}" "${2}"
         return ${?}
      ;;
      *)
         liram_manage_log_warn \
            "restore-mount: unknown mount state '${1}' for ${2}"
         liram_manage_autodie "${1}" "${2}"
         return ${?}
      ;;
   esac
}


# void liram_manage_check_sysdisk_vars()
#
liram_manage_check_sysdisk_vars() {
   liram_manage_check_vars LIRAM_DISK LIRAM_DISK_MP
}

# @liram_manage_locate_disk sysdisk liram_manage_get_sysdisk() [LIRAM_DISK]
#
liram_manage_get_sysdisk() {
   local DISK_DEV
   liram_manage__locate_disk "${LIRAM_DISK}" && \
      LIRAM_DISK_DEV="${DISK_DEV}"
}

# @liram_manage_mount sysdisk liram_manage_mount_sysdisk() [LIRAM_DISK]
#
#  Mounts the sysdisk (liram images etc.).
#
liram_manage_mount_sysdisk() {
   local v0
   [ -n "${LIRAM_DISK_DEV-}" ] || liram_manage_get_sysdisk || return
   liram_manage_log_info "Mounting liram sysdisk at ${LIRAM_DISK_MP}"
   liram_manage__mount_disk_writable \
      "${LIRAM_DISK_MOUNT_RESTORE-}" \
      "${LIRAM_DISK_DEV:?}" "${LIRAM_DISK_MP:?}" \
      "${LIRAM_DISK_FSTYPE-}" && \
   LIRAM_DISK_MOUNT_RESTORE="${v0:?}"

}

# @liram_manage_umount sysdisk liram_manage_umount_sysdisk() [LIRAM_DISK]
#
#  Restores the previous mount state of the sysdisk.
#
liram_manage_umount_sysdisk() {
   liram_manage_log_info "Unmounting liram sysdisk"
   liram_manage__restore_mount_state \
      "${LIRAM_DISK_MOUNT_RESTORE-}" "${LIRAM_DISK_MP:?}" && \
   LIRAM_DISK_MOUNT_RESTORE=
}

# @function_alias liram_manage_unmount_sysdisk()
#  renames liram_manage_umount_sysdisk()
#
liram_manage_unmount_sysdisk() { liram_manage_umount_sysdisk "$@"; }


# void liram_manage_check_boot_vars()
#
liram_manage_check_boot_vars() {
   liram_manage_check_vars LIRAM_BOOTDISK LIRAM_BOOTDISK_MP
}

# @liram_manage_locate_disk boot liram_manage_get_boot() [LIRAM_BOOTDISK]
#
liram_manage_get_boot() {
   local DISK_DEV
   liram_manage__locate_disk "${LIRAM_BOOTDISK}" && \
      LIRAM_BOOTDISK_DEV="${DISK_DEV}"
}

# @liram_manage_mount boot liram_manage_mount_boot() [LIRAM_BOOTDISK]
#
#  Mounts the boot disk (kernel images).
#
liram_manage_mount_boot() {
   local v0
   [ -n "${LIRAM_BOOTDISK_DEV-}" ] || liram_manage_get_boot || return
   liram_manage_log_info "Mounting liram boot disk at ${LIRAM_BOOTDISK_MP}"
   liram_manage__mount_disk_writable \
      "${LIRAM_BOOTDISK_MOUNT_RESTORE-}" \
      "${LIRAM_BOOTDISK_DEV:?}" "${LIRAM_BOOTDISK_MP:?}" \
      "${LIRAM_BOOTDISK_FSTYPE-}" && \
   LIRAM_BOOTDISK_MOUNT_RESTORE="${v0:?}"
}

# @liram_manage_umount boot liram_mange_umount_boot() [LIRAM_BOOTDISK]
#
#  Restores the previous mount state of the boot disk.
#
liram_manage_umount_boot() {
   liram_manage_log_info "Unmounting liram boot disk"
   liram_manage__restore_mount_state \
      "${LIRAM_BOOTDISK_MOUNT_RESTORE-}" "${LIRAM_BOOTDISK_MP:?}" && \
   LIRAM_BOOTDISK_MOUNT_RESTORE=
}

# @function_alias liram_manage_unmount_boot()
#  renames liram_mange_umount_boot()
#
liram_manage_unmount_boot() { liram_manage_umount_boot "$@"; }
