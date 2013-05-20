print_dev_and_id() {
   if [ -e "${dev}" ]; then
      echo "${dev##*/} := ${id}"
   fi
}

process_id_path() {
   local id="${1##*/}"
   case "${id}" in
      ata-?*-part[1-9]*)
         true
      ;;
      ata-?*)
         local dev=`readlink -f "${1}"`
         print_dev_and_id "${id}" "${dev}"
      ;;
   esac
   return 0
}

fs_foreach_symlink_do process_id_path /dev/disk/by-id/?* | sort
