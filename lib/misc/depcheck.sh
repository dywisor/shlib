# int depcheck ( *dep, **DEPCHECK_DIE=y ), raises die()
#
#  Tries to locate all dependencies (using which <dep>).
#  Prints an error message if any dependency is missing and dies if
#  DEPCHECK_DIE is set to 'y' (else non-zero return).
#
#  Returns 0 if all dependencies could be found.
#
depcheck() {
   local missing
   while [ $# -gt 0 ]; do
      qwhich "${1}" || missing="${missing-} ${1}"
      shift
   done
   if [ -n "${missing-}" ]; then
      set -- ${missing}
      eerror "The following dependencies are required but not available:"
      while [ $# -gt 0 ]; do
         eerror "${1}" '*  '
         shift
      done
      eerror "Please install them first or export DEPCHECK_DIE=n to ignore this."

      if [ "${DEPCHECK_DIE:-y}" = "y" ]; then
         die "depcheck failed."
      else
         return 5
      fi
   else
      return 0
   fi
}
