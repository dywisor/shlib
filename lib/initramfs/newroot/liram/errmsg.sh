#@section funcdef

#@funcdef @stderr void liram_errmsg <type> liram_errmsg_<type> (
#    f_print:=<default>
# )
#
# Prints an error message to stderr.
#

#@section functions

# void liram__BIG_FAT_MESSAGE ( f_print, *msg_line )
#
liram__BIG_FAT_MESSAGE() {
   # assert "${1}" in "eerror" "ewarn"
   local f_print="${1:?}"
   shift
   echo 1>&2
   ${f_print} "" \
"============================================================================="
   while [ ${#} -gt 0 ]; do
      ${f_print} "${1}" '!!!'
      shift
   done
   ${f_print} "" \
"============================================================================="
   echo 1>&2
}


# void liram_PRINT_ERROR_TO_CONSOLE ( *msg_line )
#
liram_PRINT_ERROR_TO_CONSOLE() {
   liram__BIG_FAT_MESSAGE eerror "$@"
}

# @liram_errmsg liram_disk_not_set()
#
liram_errmsg_liram_disk_not_set() {
   liram__BIG_FAT_MESSAGE "${1:-eerror}" \
      "\$LIRAM_DISK is not set." \
      "" \
      "Please specify a disk by adding liram_disk=<identifier>" \
      "to your boot args, for example:" \
      " - liram_disk=LABEL=my_disk" \
      " - liram_disk=nfs=192.168.1.10:/liram/images" \
      "" \
      "Note that net-booting requires additional options (net-setup)."
}
