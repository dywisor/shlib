# int dodir (
#    *dirs,
#    **DODIR_PREFIX=,
#    **F_DODIR_CREATED=,
#    **F_DODIR_EXISTED=,
#    **MKDIR_OPTS="-p",
#    **MKDIR_OPTS_APPEND=
# )
#
#  Ensures that the given directories exist by creating them if necessary.
#  Returns the number of directories for which creation failed.
#  IOW, the return value is zero if and only if all listed directories exist
#  at the end of this function.
#  Prefixes each directory with DODIR_PREFIX if set.
#
#  Additionally, F_DODIR_CREATED (<dir>) is called if a directory has been
#  created, and F_DODIR_EXISTED (<dir>) is called if it already exists.
#  This function immediately returns with a non-zero code if
#  any F_DODIR_* function fails.
#
dodir() {
   local fail=0 d prefix=""

   if [ -n "${DODIR_PREFIX-}" ]; then
      local d prefix
      prefix="${DODIR_PREFIX}"
      d="${prefix%/}"
      while [ "${prefix}" != "${d}" ]; do
         prefix="${d%/}"
         d="${prefix%/}"
      done
      # prefix could be empty here (if DODIR_PREFIX == '/')
      prefix="${prefix}/"

   fi

   while [ $# -gt 0 ];do
      if [ -n "${1-}" ]; then
         d="${prefix}${1}"

         if [ -d "${d}" ]; then
            [ -z "${F_DODIR_EXISTED-}" ] || \
               ${F_DODIR_EXISTED} "${d}" || return
         elif mkdir ${MKDIR_OPTS--p} ${MKDIR_OPTS_APPEND-} -- "${d}"; then
            [ -z "${F_DODIR_CREATED-}" ] || \
               ${F_DODIR_CREATED} "${d}" || return
         else
            fail=$(( ${fail} + 1 )) || true
         fi
      fi
      shift
   done

   return ${fail}
}
