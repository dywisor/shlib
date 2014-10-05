#@HEADER
# initramfs/cmdline/parse: TODO: use argparse_minimal

#@section functions

# void cmdline_parse ( **CMDLINE_FILE=/proc/cmdline )
#
#  Parses /proc/cmdline by calling __cmdline_parse_mux(<arg>) for each arg.
#
cmdline_parse() {
   local \
      F_ARGPARSE=__cmdline_parse_mux \
      ARGPARSE_LOG_UNKNOWN="warn" \
      F_ARGPARSE_BREAK= \
      F_ARGPARSE_ARG= \
      F_ARGPARSE_SHORTOPT= \
      F_ARGPARSE_LONGOPT=

   local line argv iter

   # read cmdline files built into the initramfs image
   for iter in /cmdline /liram/cmdline; do
      if [ -f "${iter}" ]; then
         # concat all non-empty, non-comment lines and store them in %argv
         argv=
         while read -r line; do
            case "${line}" in
               ''|'#'*)
                  true
               ;;
               *)
                  argv="${argv} ${line}"
               ;;
            esac
         done < "${iter}"

         # parse %argv
         if [ -n "${argv}" ]; then
            argparse_parse ${argv}
            argv=
         fi
      fi
   done

   # read cmdline
   argparse_parse_from_file "${CMDLINE_FILE:-/proc/cmdline}"
}

# void __cmdline_parse_mux ( ..., **__CMDLINE_ARGPARSE_FUNCTIONS )
#
#  Calls (registered) cmdline parser functions until the first one succeeds.
#
#  Always returns 0.
#
__cmdline_parse_mux() {
   local func
   for func in ${__CMDLINE_ARGPARSE_FUNCTIONS-}; do
      if ${func} "$@"; then
         return 0
      fi
   done

   if __debug__; then
      # nobody cared about arg, call argparse_unknown()
      argparse_unknown
   fi
}
