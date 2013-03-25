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
   # nobody cared about arg, call argparse_unknown()
   argparse_unknown
}
