# @private int fslevel__get_level ( normalized_fspath, **v0! )
#
#  See get_fs_level().
#
fslevel__get_level() {
   : ${1?}
   v0=

   if [ -z "${1}" ] || [ "${1}" = "/" ]; then
      v0=0
   else
      local b="${1}"
      local a="${b%/*}"
      local i=0

      #[ "${a#/}" = "${a}" ] || i=1

      while [ "${a}" != "${b}" ]; do
         i=$(( ${i} + 1 ))
         b="${a}"
         a="${b%/*}"
      done

      v0="${i}"
   fi

   [ -n "${v0}" ]
}

# int get_fslevel ( fspath, **v0! )
#
#  Determines the level of the given filesystem path and stores the result
#  in v0 if successful.
#
#  The file system level is defined as the number of slashes in %fspath
#  followed by a non-empty char sequence (/a/b->2,/a//b->3).
#  A more strict definition would require the char sequence not to
#  contain the slash char (/a/b->2,/a//b->2; not implemented).
#
#  The path is cleaned up before determining the level.
#
get_fslevel() {
   fspath_remove_trailing_slashes "${1?}"
   fslevel__get_level "${v0}"
}

# @function_alias get_fs_level() renames get_fslevel()
#
get_fs_level() { get_fslevel "$@"; }

# int get_fslevel_diff ( root, subpath, **v0! )
#
#  Compares the level of two filesystem paths where %root is the root of
#  %subpath (or vice versa) and returns the difference
#  level(subpath) - level(root) via %v0.
#
get_fslevel_diff() {
   : ${1?} ${2?}
   local a b x negate=0
   local root sub

   fspath_remove_trailing_slashes "${1}"
   #get_abspath "${1}"
   root="${v0}"

   fspath_remove_trailing_slashes "${2}"
   #get_abspath "${1}"
   sub="${v0}"

   case "${sub}" in
      "${root%/}/"*)
         x="${sub#${root%/}}"
      ;;
      "${root}")
         v0=0
         return 0
      ;;
      *)
         case "${root}" in
            "${sub%/}/"*)
               negate=1
               x="${root#${sub%/}}"
            ;;
            *)
               v0=
               return 1
            ;;
         esac
      ;;
   esac

   get_fslevel "${x}"
   [ ${negate} -eq 0 ] || v0="-${v0}"
   return 0
}

# @function_alias get_fs_level_diff() renames get_fslevel_diff()
#
get_fs_level_diff() { get_fslevel_diff "$@"; }
