#@section functions_private

# @private int fs_foreach__do_if (
#    test_condition, func, *fs_item, **F_FS_FOREACH_ON_ERROR=return
# )
# DEFINES @fs_foreach <test_condition>|<test_condition-name> <function_name>
#  AS int <function_name> (
#     <test_condition>, func, *fs_item, **F_FS_FOREACH_ON_ERROR
#  )
#
#  Calls
#   %func ( <fs_item> ) for each <fs_item> if test -%test_condition <fs_item>
#
fs_foreach__do_if() {
   local cond="${1:?}" f="${2:?}"
   shift 2
   while [ $# -gt 0 ]; do
      [ ! -${cond} "${1}" ] || ${f} "${1}" || ${F_FS_FOREACH_ON_ERROR:-return}
      shift
   done
}


#@section functions_public

# int fs_foreach_do_if (
#    f_condition, func, *fs_item, **F_FS_FOREACH_ON_ERROR=return
# )
#
#  Calls
#   %func ( <fs_item> ) for each <fs_item> if %f_condition ( <fs_item> )
#
fs_foreach_do_if() {
   local f_cond="${1:?}" f="${2:?}"
   shift 2
   while [ $# -gt 0 ]; do
      ! ${f_cond} "${1}" || ${f} "${1}" || ${F_FS_FOREACH_ON_ERROR:-return}
   done
}

# @fs_foreach file fs_foreach_file_do()
# @fs_foreach file foreach_file_do()
fs_foreach_file_do() { fs_foreach__do_if f "$@"; }
foreach_file_do()    { fs_foreach__do_if f "$@"; }

# @fs_foreach dir fs_foreach_dir_do()
# @fs_foreach dir foreach_dir_do()
fs_foreach_dir_do() { fs_foreach__do_if d "$@"; }
foreach_dir_do()    { fs_foreach__do_if d "$@"; }

# @fs_foreach symlink fs_foreach_symlink_do()
# @fs_foreach symlink foreach_symlink_do()
#
fs_foreach_symlink_do() { fs_foreach__do_if h "$@"; }
foreach_symlink_do()    { fs_foreach__do_if h "$@"; }

# @fs_foreach e fs_foreach_do()
fs_foreach_do() { fs_foreach__do_if e "$@"; }
