__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_core
"

cmdline_parser_core() {
   case "${arg}" in
      mdev)
         initramfs_enable_use mdev
      ;;
      lvm)
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
      *)
         return 1
      ;;
   esac
}
