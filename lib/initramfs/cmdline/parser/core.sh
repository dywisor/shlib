__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_core
"

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
      *)
         return 1
      ;;
   esac
}
