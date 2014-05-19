#@section functions

initramfs_zram_autoswap() {
   [ "${CMDLINE_WANT_ZRAM_SWAP:-n}" = "y" ] || return 0
   irun zram_autoswap "${CMDLINE_ZRAM_SWAP_SIZE-}"
}
