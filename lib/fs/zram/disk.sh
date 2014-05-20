#@section functions

# @private::protected int zram_disk__from_vars (
#    *mkfs_args,
#    **size_m, **mp, **mount_opts, **fstype, **mode, **owner,
#    **ZRAM_!
# )
#
#  Internal wrapper for zram_init_any() + zram_disk_mount().
#
zram_disk__from_vars() {
   zram_init_any "${size_m?}" disk "${fstype?}" "${@}" && \
   zram_disk_mount \
      "${mp?}" "${mount_opts?}" "${fstype?}" "${mode?}" "${owner?}"
}

# @zram_init_any zram_disk (
#    size_m, mp, mount_opts=rw,noatime, fstype:=auto, mode=, owner=,
#    *mkfs_args, **ZRAM_!
# )
#
#  Initializes a zram disk device of the given size,
#  creates a filesystem of type %fstype with args %mkfs_args for it
#  and mounts it at %mp with the given %mount_opts.
#
#  Optionally adjusts permissions/ownership of the mountpoint (after mounting),
#  which requires a writable mount ("ro" not in %mount_opts).
#
zram_disk() {
   local size_m mp mount_opts fstype mode owner

   size_m="${1:?}"
   mp="${2:?}"
   mount_opts="${3:-rw,noatime}"
   fstype="${4:-auto}"
   mode="${5-}"
   owner="${6-}"

   if [ ${#} -gt 6 ]; then
      shift 6 && zram_disk__from_vars "${@}"
   else
      zram_disk__from_vars
   fi
}

# @zram_type_init zram_init__disk ( fstype:=<default>, *mkfs_args, **ZRAM_ )
#
#  Creates a filesystem. See zram_disk_mkfs() for details.
#
zram_init__disk() {
   zram_disk_mkfs "${@}"
}

# int zram_disk_umount ( **ZRAM_DEV )
#
#  Unmounts %ZRAM_DEV, assuming that it was mounted as disk.
#
zram_disk_umount() {
   zram_log_info "Unmounting ${ZRAM_DEV}"
   ${AUTODIE_NONFATAL-} do_unmount "${ZRAM_DEV:?}"
}

# zram_disk_mount ( mp, opts=, fstype=auto, mode=, owner=, **ZRAM_DEV )
#
#  Mounts %ZRAM_DEV at the given mountpoint, with the given %fstype and %opts.
#
#  Optionally sets permissions/ownership after mounting, which requires
#  a non-readonly mount.
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

# int zram_disk_mkfs ( fstype:=ext4, *args, **ZRAM_DEV, **ZRAM_FS_NAME )
#  @calls zram_disk_mkfs_%fstype ( *args )
#
#  Creates a filesystem for %ZRAM_DEV by calling the fstype-specific
#  mkfs function zram_disk_mkfs_%fstype(*args).
#
#  %ZRAM_FS_NAME should be used as filesytem name (label) if applicable.
#
#  %fstype defaults to ext4 if empty or set to "auto".
#
#  Returns: success (true/false)
#
zram_disk_mkfs() {
   local fstype="${1:-ext4}"
   [ -z "${1+SET}" ] || shift

   case "${fstype}" in
      ext4|auto)
         #@debug function_defined zram_disk_mkfs_ext4 || function_die
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
