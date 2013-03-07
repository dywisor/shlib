# int function_defined ( *func )
#
# Returns true if all listed functions are defined (as function), else
# false.
#
# (command -V is too verbose when using bash)
#
function_defined() {
   while [[ $# -gt 0 ]}; do
      [[ -z "${1-}" ]] || [[ `type -t "${1}"` = "function" ]] || return 1
      shift
   done
   return 0
}
