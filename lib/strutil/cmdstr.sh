#@section functions

get_cmd_str() {
   v0=

   while [ $# -gt 0 ] && [ -z "${1}" ]; do shift; done

   [ $# -gt 0 ] || return 1

   while [ $# -gt 0 ]; do
      case "${1}" in
         ''|*' '*|*[\/\$\;\&\|]*)
            # ^ incomplete list
            v0="${v0} \"${1}\""
         ;;
         *)
            v0="${v0} ${1}"
         ;;
      esac
      shift
   done

   v0="${v0# }"
}
