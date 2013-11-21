#@section module_init_vars
__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_disk
"

#@section functions

__cmdline_parser_disk_premount() {
   CMDLINE_PREMOUNT="${CMDLINE_PREMOUNT-} $*"
}

cmdline_parser_disk() {
   case "${arg}" in
      # rootfs
      root)
         CMDLINE_ROOT="${value}"
      ;;
      rootfstype)
         CMDLINE_ROOTFSTYPE="${value}"
      ;;
      rootfsflags)
         CMDLINE_ROOTFSFLAGS="${value}"
      ;;
      ro)
         CMDLINE_ROOT_RO=y
      ;;
      rw)
         CMDLINE_ROOT_RO=n
      ;;

      # /etc
      etc)
         CMDLINE_ETC="${value}"
      ;;
      etcfstype)
         CMDLINE_ETCFSTYPE="${value}"
      ;;
      etcfsflags)
         CMDLINE_ETCFSFLAGS="${value}"
      ;;
      etc_ro)
         CMDLINE_ETC_RO=y
      ;;
      etc_rw)
         CMDLINE_ETC_RO=n
      ;;

      # other disks
      premount)
         : ${CMDLINE_PREMOUNT=}
         F_ITER=__cmdline_parser_disk_premount list_iterator "${value}"
      ;;
      no_usr)
         CMDLINE_NO_USER=y
      ;;

      # fsck
      no_root_fsck)
         CMDLINE_ROOT_FSCK=n
      ;;
      no_fsck)
         CMDLINE_FSCK=n
      ;;

      # default return
      *)
         return 1
      ;;
   esac
}
