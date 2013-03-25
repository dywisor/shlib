# int qwhich ( *binary )
#
#  Returns 0 if all listed binaries are found by which, else 1.
#
qwhich() {
   while [ $# -gt 0 ]; do
      [ -z "${1-}" ] || which "${1}" 1>${DEVNULL} 2>${DEVNULL} || return 1
      shift
   done
   return 0
}
