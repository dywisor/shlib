#@section module_init_vars
__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_liram
"

#@section functions

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
      'zram')
         LIRAM_ROOTFS_TYPE="${k}"
         LIRAM_ROOTFS_ZRAM_FSTYPE="${v:-auto}"
      ;;
      'layout')
         LIRAM_LAYOUT="${v}"
      ;;
      'layout_uri')
         LIRAM_LAYOUT_URI="${v}"
      ;;
      'layout_file')
         if [ -n "${v}" ]; then
            LIRAM_LAYOUT_URI="file://${v}"
         else
            LIRAM_LAYOUT_URI=
         fi
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
      'novdr')
         LIRAM_LAYOUT_TV_WITH_VDR=n
      ;;
      'hybrid')
         # normalize yesno value
         if [ -z "${v}" ] || word_is_yes "${v}"; then
            LIRAM_LAYOUT_HYBRID=y
         elif word_is_no "${v}"; then
            LIRAM_LAYOUT_HYBRID=n
         else
            LIRAM_LAYOUT_HYBRID="${v}"
         fi
      ;;
      'nohybrid')
         LIRAM_LAYOUT_HYBRID=n
      ;;
      'secure')
         # there is no 'secure' mode
         #  However, certain actions are known to be really insecure
         #  (e.g. loading/executing code from disk/nfs, ...),
         #  which can be prevented by setting LIRAM_INSECURE=n.
         #
         #  The interpretation of this variable is mostly up
         #  to the liram layout being loaded, but also affects the
         #  decision whether a specific layout file can be loaded.
         #
         #  A value of "n" is sticky
         #  (cannot be changed by further cmdline args).
         #
         LIRAM_INSECURE=n
      ;;
      'insecure')
         if [ -z "${v}" ] || word_is_yes "${v}"; then
            if [ "${LIRAM_INSECURE:-X}" = "n" ]; then
               ${LOGGER} --level=WARN --facility=cmdline.liram "ignoring ${real_arg}"
            else
               : ${LIRAM_INSECURE:=y}
            fi
         else
            LIRAM_INSECURE=n
         fi
      ;;
      *)
         ${LOGGER} --level=WARN --facility=cmdline.liram "unknown option '${1}'"
         LIRAM_CMDLINE_ARGS="${LIRAM_CMDLINE_ARGS-} ${1}"
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
      liram_hybrid)
         __cmdline_parser_liram_opts "hybrid=${value}"
      ;;

      # default return
      *)
         return 1
      ;;
   esac
   NEWROOT_TYPE=liram
}
