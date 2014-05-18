#@section functions

# int zram_disk_init ( ident, size_m, *mkfs_args, **ZRAM_! )
#
zram_disk_init() {
   zram_init "${1?}" "${2:?}" && \
   shift 2 && \
   zram_disk_mkfs "${@}"
}

# int zram_disk_setup (
#    ident, size_m, mp, fstype:=auto, mount_opts=, mode=, owner=
# )
#
#  Note that you cannot pass any mkfs options when using this function.
#
zram_disk_setup() {
   zram_disk_init "${1?}" "${2:?}" "${4:-auto}" && \
   zram_disk_mount "${3:?}" "${5-}" "${4:-auto}" "${6-}" "${7-}"
}


# int zram_disk_umount ( **ZRAM_DEV )
#
zram_disk_umount() {
   zram_log_info "Unmounting ${ZRAM_DEV}"
   ${AUTODIE_NONFATAL-} do_unmount "${ZRAM_DEV:?}"
}

# zram_disk_mount ( mp, opts=, fstype=auto, mode=, owner=, **ZRAM_DEV )
#
zram_disk_mount() {
   zram_log_info "Mounting ${ZRAM_DEV} at ${1:-%UNSET%}"
   ${AUTODIE_NONFATAL-} domount_fs \
      "${1:?}" "${ZRAM_DEV:?}" "${2-}" "${3:-auto}" || return

   # create a ".keep_zram" file
   #  (doesn't work if %mp was mounted readonly, so suppress any output)
   {
      touch "${1}/.keep_zram" && chmod -- 0444 "${1}/.keep_zram" || true
   } 1>>${DEVNULL} 2>>${DEVNULL}

   [ -z "${4-}" ] || ${AUTODIE_NONFATAL-} chmod -- "${4}" "${1}" || return
   [ -z "${5-}" ] || ${AUTODIE_NONFATAL-} chown -- "${5}" "${1}" || return

   return 0
}

# int zram_disk_mkfs ( fstype:=ext4, *args )
#  @calls zram_disk_mkfs_%fstype ( *args )
#
zram_disk_mkfs() {
   local fstype="${1:-ext4}"
   [ -z "${1+SET}" ] || shift

   case "${fstype}" in
      ext4|auto)
         zram_log_info "Creating ext4 filesystem on ${ZRAM_DEV:?}"
         ${AUTODIE_NONFATAL-} zram_disk_mkfs_ext4 "${@}"
      ;;

      *)
         if function_defined zram_disk_mkfs_${fstype}; then
            zram_log_info "Creating ${fstype} filesystem on ${ZRAM_DEV:?}"
            ${AUTODIE_NONFATAL-} zram_disk_mkfs_${fstype} "${@}"
         else
            zram_log_error "Cannot create filesystem: ${fstype} not supported."
            return 10
         fi
      ;;
   esac
}
