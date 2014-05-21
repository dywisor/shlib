#@section vars

# tri-state: <0: never; 0: try zram, fall back to tmpfs, >0: use tmpfs
: ${INITRAMFS_ZRAM_FALLBACK_TO_TMPFS:=0}

## alternatively, store the number of free devices and allocate zram||tmpfs
## based on this value
##INITRAMFS_ZRAM_NUM_FREE=
## + void initramfs_zram_reset_free(**INITRAMFS_ZRAM_NUM_FREE!)

#@section functions

initramfs_zram_autoswap() {
   [ "${CMDLINE_WANT_ZRAM_SWAP:-n}" = "y" ] || return 0
   irun zram_autoswap "${CMDLINE_ZRAM_SWAP_SIZE-}"
}

# void initramfs_zram_dotmpfs (
#    mp, name=, opts=, fstype=auto, **INITRAMFS_ZRAM_FALLBACK_TO_TMPFS!
# )
#
#  * %fstype is discarded when falling back to tmpfs
#
initramfs_zram_dotmpfs() {
   local v0

   if [ ${INITRAMFS_ZRAM_FALLBACK_TO_TMPFS} -eq 0 ]; then

      if inonfatal zram_dotmpfs "${@}"; then
         return 0

      # could also establish a ZRAM_ERR_NO_FREE_DEVICE return value
      #elif [ ${?} -eq ${ZRAM_ERR_NODEV_FREE:?} ]; then
      elif ! zram_get_free_device_count || [ ${v0:-0} -eq 0 ]; then
         dolog --level=WARN \
            "zram: no free devices available, falling back to tmpfs"
         INITRAMFS_ZRAM_FALLBACK_TO_TMPFS=1

         # discard %fstype, dotmpfs() uses ${arg:-X} for all pos args,
         # so no need to reorder args here
         irun dotmpfs "${1-}" "${2-}" "${3-}"

      else
         initramfs_die "failed to create tmpfs-like zram device!"
      fi

   elif [ ${INITRAMFS_ZRAM_FALLBACK_TO_TMPFS} -gt 0 ]; then
      dolog --level=INFO "zram: directly falling back to tmpfs"
      irun dotmpfs "${1-}" "${2-}" "${3-}"

   else
      # could also mean that %INITRAMFS_ZRAM_FALLBACK_TO_TMPFS is not a number
      irun zram_dotmpfs "${@}"
   fi
}
