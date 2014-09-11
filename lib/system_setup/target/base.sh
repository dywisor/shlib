#@section functions

# @lazy-export all from .depend


DONT_OVERRIDE_FUNCTION run_dmc
run_dmc() { print_cmd "$@"; "$@"; }

DONT_OVERRIDE_FUNCTION run_cmd
run_cmd() { run_dmc "$@"; }

DONT_OVERRIDE_FUNCTION is_target_path
is_target_path() {
   case "${1:?}" in
      "${TARGET_DIR%/}"|"${TARGET_DIR%/}/"*)
         return 0
      ;;
   esac

   return 1
}

# void check_is_target_path ( path, [desc] ), raises die()
DONT_OVERRIDE_FUNCTION check_is_target_path
check_is_target_path() {
   is_target_path "${1:?}" || \
      die "${2:-path} outside of target dir ${TARGET_DIR%/}: ${1}"
}

DONT_OVERRIDE_FUNCTION apply_target_path_prefix
apply_target_path_prefix() {
   # could merge with get_target_path()

   if is_target_path "${1:?}"; then
      v0="${1}"
   else
      v0="${TARGET_DIR%/}/${1#/}"
   fi
}

DONT_OVERRIDE_FUNCTION get_target_path
get_target_path() {
   case "${1-}" in
      ''|'/')
         v0="${TARGET_DIR:?}"

      ;;
      *)
         v0="${TARGET_DIR:?}/${1#/}"
      ;;
   esac
}

# normalizes a rooted path ("/../"->"/", "/a/../b"->"/b")
DONT_OVERRIDE_FUNCTION target_normpath
target_normpath() {
   : ${1:?}
   v0=

   case "${1:?}" in
      "${TARGET_DIR%/}"|"${TARGET_DIR%/}/"*)
         die "bad usage"
      ;;
   esac

   local IFS="/"
   set -- ${1#/}
   IFS="${IFS_DEFAULT?}"

   v0="/"
   while [ $# -gt 0 ]; do
      case "${1}" in
         '.'|'')
            shift
         ;;
         '..')
            v0="${v0%/*}"
            shift
         ;;
         *)
            # peek at $2
            if [ "${2:-X}" = ".." ]; then
               shift 2
            else
               v0="${v0%/}/${1}"
               shift
            fi
         ;;
      esac
   done

   : ${v0:=/}
}
