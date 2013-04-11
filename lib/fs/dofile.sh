# int dofile ( file, str=, dofile_create=**DOFILE_CREATE=y )
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
      if [ -z "${d}" ] || dodir_clean "${d}"; then
         echo "${2-}" > "${1}"
      else
         return 1
      fi
   else
      return 0
   fi
}

# @function_alias int dofile_if ( file, str= )
#  is dofile ( file, str=, "n" )
#
dofile_if() { dofile "${1-}" "${2-}" "n"; }
