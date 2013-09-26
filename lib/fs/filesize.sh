# int get_filesize ( fs_item )
#
#  Determines the size of a file or directory in MiB.
#  Stores the result in FILESIZE if successful and returns 0,
#  else returns 1 and sets FILESIZE to -1.
#
get_filesize() {
   FILESIZE="-1"
   if [ -n "${1-}" ] && [ -e "${1-}" ]; then
      local size=$(du -xms "${1}" | sed -r -e 's=\s.*$==')

      if [ -n "${size}" ]; then
         # busybox' du returns 0 for small files
         if [ ${size} -gt 0 ]; then
            FILESIZE="${size}"
         else
            FILESIZE=1
         fi
         return 0
      fi
   fi
   return 1
}
