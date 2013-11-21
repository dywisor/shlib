#@section header
# This module provides generic file search functions
# !!! It is not a file scanning "frontend", see liram/util->liram_scan_files()


#@section functions

# void liram_filescan() {
#    *file_name,
#    **FILE_SCAN_DIR="",
#    **FILE_SCAN_EXTENSIONS,
#    **FILE_SCAN_SYNC_DIR,
# )
#
#  Scans for <file name>.<file ext> in FILE_SCAN_DIR and creates
#  FILE_SCAN_SYNC_DIR/<file name> symlinks for each file found (first hit
#  per name).
#
liram_filescan() {
   : ${FILE_SCAN_SYNC_DIR:?}
   irun dodir_clean "${FILE_SCAN_SYNC_DIR}" || return

   [ $# -gt 0 ] && [ -n "${FILE_SCAN_EXTENSIONS-}" ] || return 0

   local SCAN_DIR="${FILE_SCAN_DIR-}"
   [ -z "${SCAN_DIR}" ] || SCAN_DIR="${SCAN_DIR%/}/"


   # the expected case is that all file have the same file extension,
   # so iterate over FILE_SCAN_EXTENSIONS in the outer loop
   #
   local ext name file file_count=0

   for ext in ${FILE_SCAN_EXTENSIONS}; do
      for name; do
         if [ ! -e "${FILE_SCAN_SYNC_DIR}/${name}" ]; then
            # else $name already found
            #  (possibly not during this run, but this won't be detected here)

            file="${SCAN_DIR}${name}.${ext#.}"
            if [ -f "${file}" ]; then
               if inonfatal ln -s -f ${LN_OPT_NO_TARGET_DIR-} -- \
                     "${file}" "${FILE_SCAN_SYNC_DIR}/${name}"
               then
                  file_count=$(( ${file_count} + 1 ))
               fi
            fi
         fi
      done
      [ ${file_count} -lt ${#} ] || break
   done

   return 0
}

# int liram_filescan_get ( name, sync_dir )
#
#  Resolves the symlink of a (previously found) files and stores the
#  result in %v0.
#
#  Returns 0 if the file exists, else != 0.
#
liram_filescan_get() {
   v0=
   local SYNC_DIR="${2?}"
   [ -z "${SYNC_DIR}" ] || SYNC_DIR="${SYNC_DIR%/}/"

   if [ ! -d "${SYNC_DIR}" ]; then
      return 5

   elif [ -e "${SYNC_DIR}${1:?}" ]; then
      v0=$(readlink -f "${SYNC_DIR}${1}")
      if [ -f "${v0}" ]; then
         return 0
      else
         return 2
      fi

   elif [ -h "${SYNC_DIR}${1:?}" ]; then
      return 9

   else
      return 1
   fi
}
