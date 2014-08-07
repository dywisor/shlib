#@section functions

stat_print_dev_number() {
   stat -c '%D' "${@}"
}

is_one_same_fs() {
   local dev_numbers
   dev_numbers="$(stat_print_dev_number "${@}")"

   [ ${?} -eq 0 ] || return 5

   set -- ${dev_numbers}
   while [ ${#} -gt 1 ]; do
      [ "${1}" = "${2}" ] || return 1
      shift
   done

   return 0
}

parent_is_on_same_fs() {
   [ ${#} -gt 0 ] || return 64

   local parent

   while [ ${#} -gt 0 ]; do
      [ -e "${1}" ] || [ -h "${1}" ] || return 5

      parent="$(dirname "${1}")"
      [ -d "${parent}" ] || return 6

      is_one_same_fs "${parent}" "${1}" || return 1

      shift
   done

   return 0
}
