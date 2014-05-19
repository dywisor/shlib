#@section module_init_vars
__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_core
"

#@section functions

cmdline_parser_core() {
   case "${arg}" in
      mdev)
         initramfs_enable_use mdev
      ;;
      lvm|lvm2)
         CMDLINE_LVM=y
      ;;
      mdadm|softraid)
         CMDLINE_MDADM=y
      ;;
      real_init)
         CMDLINE_INIT="${value}"
      ;;
      rootdelay)
         CMDLINE_ROOTDELAY="${value}"
      ;;
      home|home_dir)
         NEWROOT_HOME_DIR="${NEWROOT?}/${value#/}"
      ;;
      debuglog)
         DEBUG=y
      ;;
      doshell)
         CMDLINE_WANT_SHELL=y
      ;;
      zram_swap)
         CMDLINE_WANT_ZRAM_SWAP=y
         CMDLINE_ZRAM_SWAP_SIZE="${value}"
      ;;
      *)
         return 1
      ;;
   esac
}
