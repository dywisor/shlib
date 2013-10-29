# int qwhich ( *prog )
#
#  Returns 0 if all listed programs are found by which, else 1.
#
qwhich() {
   while [ $# -gt 0 ]; do
      [ -z "${1-}" ] || which "${1}" 1>${DEVNULL} 2>${DEVNULL} || return 1
      shift
   done
   return 0
}

# int qwhich_single ( prog, **v0! )
#
#  Returns 0 if the given program could be found by which, else 1.
#  Also stores the path to the program in %v0.
#
qwhich_single() {
   : ${1:?}
   v0=$( which "${1}" 1>${DEVNULL} 2>${DEVNULL} )
   [ -n "${v0}" ]
}
