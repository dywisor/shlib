#@section module_init_vars
__CMDLINE_ARGPARSE_FUNCTIONS="${__CMDLINE_ARGPARSE_FUNCTIONS-}
cmdline_parser_net
"

#@section functions

cmdline_parser_net__append() {
   CMDLINE_NET_CONFIG="${CMDLINE_NET_CONFIG-}${CMDLINE_NET_CONFIG:+ }${*}"
}

cmdline_parser_net() {
   case "${arg}" in
      net|netcfg|netconfig)
         [ -z "${value}" ] || cmdline_parser_net__append "${value}"
      ;;
      eth*|bridge*|wifi*|wlan*|tun*|tap*|bond*)
         cmdline_parser_net__append "${real_arg}"
      ;;
      *)
         return 1
      ;;
   esac
}
