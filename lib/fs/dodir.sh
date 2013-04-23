# @extern int dodir_minimal (  dir, **KEEPDIR=n )
# @extern int dodir_clean   ( *dir, **KEEPDIR=n )

# int dodir (
#    *dir,
#    **DODIR_PREFIX=,
#    **F_DODIR_CREATED=,
#    **F_DODIR_EXISTED=,
#    **F_DODIR_EXISTED_FILE=,
#    **MKDIR_OPTS="-p",
#    **MKDIR_OPTS_APPEND=,
#    **KEEPDIR=n
# )
#
#  Ensures that the given directories exist by creating them if necessary.
#  Returns the number of directories for which creation failed.
#  IOW, the return value is zero if and only if all listed directories exist
#  at the end of this function.
#  Prefixes each directory with DODIR_PREFIX if set.
#
#  Additionally,
#  calls F_DODIR_CREATED (<dir>) for each created directory,
#  F_DODIR_EXISTED (<dir>) for existing directories and
#  F_DODIR_EXISTED_FILE (<dir>) if <dir> exists, but is a file.
#
#  This function immediately returns a non-zero code if any F_DODIR_*
#  function fails.
#
dodir() {
   local fail=0 v0 d prefix=""

   if [ -n "${DODIR_PREFIX-}" ]; then
      fs_doprefix "" "${DODIR_PREFIX}"
      prefix="${v0%/}/"
   fi

   while [ $# -gt 0 ];do
      if [ -n "${1-}" ]; then
         d="${prefix}${1}"

         if [ -d "${d}" ]; then

            [ "${KEEPDIR:-n}" != "y" ] || \
               [ -e "${d}/.keep" ] || touch "${d}/.keep" || true

            [ -z "${F_DODIR_EXISTED-}" ] || \
               ${F_DODIR_EXISTED} "${d}" || return


         elif mkdir ${MKDIR_OPTS--p} ${MKDIR_OPTS_APPEND-} -- "${d}" 2>/dev/null; then

            [ "${KEEPDIR:-n}" != "y" ] || touch "${d}/.keep" || true

            [ -z "${F_DODIR_CREATED-}" ] || \
               ${F_DODIR_CREATED} "${d}" || return

         elif [ -f "${d}" ] && [ -n "${F_DODIR_EXISTED_FILE-}" ]; then

            ${F_DODIR_EXISTED_FILE} "${d}" || return

         else
            fail=$(( ${fail} + 1 )) || true
         fi
      fi
      shift
   done

   return ${fail}
}

# void dodir_zap_env()
#
#  Unsets all dodir()-related variables.
#
dodir_zap_env() {
   unset DODIR_PREFIX \
      F_DODIR_CREATED F_DODIR_EXISTED F_DODIR_EXISTED_FILE \
      MKDIR_OPTS MKDIR_OPTS_APPEND
}

# int keepdir ( *dir, **<see dodir()> )
#
#  Same as dodir(), but always passes KEEPDIR=y.
#
keepdir() { KEEPDIR=y dodir "$@"; }
