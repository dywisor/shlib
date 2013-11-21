#@section functions_public

# int dofile (
#    file, str=, dofile_create=**DOFILE_CREATE=y, DOFILE_WARN_MISSING=n
# )
#
#  Writes str to file.
#
dofile() {
   : ${1:?}

   if [ -e "${1}" ]; then
      echo "${2-}" > "${1}"
   elif [ "x${3-${DOFILE_CREATE:-y}}" = "xy" ]; then
      # ${1%/*} as dirpath is sufficient here
      local d="${1%/*}"
      if [ -z "${d}" ] || dodir_minimal "${d}"; then
         echo "${2-}" > "${1}"
      else
         return 1
      fi
   elif [ "${DOFILE_WARN_MISSING:-n}" = "y" ]; then
      if [ "${HAVE_MESSAGE_FUNCTIONS:-n}" = "y" ]; then
         ewarn "dofile(): ${1} does not exist."
      else
         echo "dofile(): ${1} does not exist." 1>&2
      fi
      return 0
   else
      return 0
   fi
}

# @function_alias int dofile_if ( file, str= )
#  is dofile ( file, str=, "n" )
#
dofile_if() { dofile "${1-}" "${2-}" "n"; }
