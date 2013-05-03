__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_liram
"

__cmdline_parser_liram_opts() {
   local k="${1%%=*}" v="${1#*=}"
   [ "${v}" != "${k}" ] || v=

   case "${k}" in
      'disk'|'sysdisk')
         LIRAM_DISK="${v}"
      ;;
      'fstype'|'disktype'|'sysdisktype')
         LIRAM_DISK_FSTYPE="${v}"
      ;;
      'slot')
         LIRAM_SLOT="${v#/}"
      ;;
      'size'|'rootfs_size')
         LIRAM_ROOTFS_SIZE="${v}"
      ;;
      'layout')
         LIRAM_LAYOUT="${v}"
      ;;
      'home_size')
         LIRAM_HOME_TMPFS_SIZE="${v}"
      ;;
      'etc_size')
         LIRAM_ETC_TMPFS_SIZE="${v}"
      ;;
      'usr_size')
         LIRAM_USR_TMPFS_SIZE="${v}"
      ;;
      'experimental')
         LIRAM_EXPERIMENTAL=y
      ;;
      *)
         ${LOGGER} --level=WARN --facility=cmdline.liram "unknown option '${1}'"
      ;;
   esac
}

cmdline_parser_liram() {
   case "${arg}" in
      liram)
         [ -z "${value}" ] || F_ITER=__cmdline_parser_liram_opts list_iterator "${value}"
      ;;
      liram_disk)
         __cmdline_parser_liram_opts "disk=${value}"
      ;;
      liram_disktype)
         __cmdline_parser_liram_opts "disktype=${value}"
      ;;
      liram_slot)
         __cmdline_parser_liram_opts "slot=${value}"
      ;;
      liram_size)
         __cmdline_parser_liram_opts "size=${value}"
      ;;
      liram_layout)
         __cmdline_parser_liram_opts "layout=${value}"
      ;;

      # default return
      *)
         return 1
      ;;
   esac
   NEWROOT_TYPE=liram
}
