
# int tmpdir_cleanup ( dir=[T=""] )
#
# Removes the given directory (if it exists). (For atexit).
#
tmpdir_cleanup() {
   local d="${1:-${T:-}}"
   if [ -n "${d}" ] && [ -d "${d}" ]; then
      rm -r "${d}"
   fi
}

# int get_tmpdir ( tmpdir_suffix, **GET_TMPDIR_QUIET=y )
#
# Creates a temporary directory that will be wiped at exit.
# The dir will be stored in T and printed to stdout unless GET_TMPDIR_QUIET
# is set to 'y'.
#
get_tmpdir() {
   T=$(mktemp -d "${TMPDIR:-/tmp}/${1:-shlib}.XXXXXXXXXX")
   if [ -n "${T}" ]; then
      atexit_register tmpdir_cleanup "${T}"
      [ "${GET_TMPDIR_QUIET:-y}" = "y" ] || echo "${T}"
   else
      return 1
   fi
}
