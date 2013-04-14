# int get_fslevel ( fspath )
#
#  Determines the level of the given filesystem path and stores the result
#  in v0 if successful.
#
#  Expects canonical filesystem paths, trailing slash chars are accepted.
#
get_fslevel() {
   v0=
   local a="${1?}" b="${1%/}"

   # remove trailing "/" chars
   while [ "x${a}" != "x${b}" ]; do
      a="${b%/}"
      b="${a%/}"
   done

   if [ -z "${a}" ]; then
      v0=0
   else
      local i=0

      b="${a}"
      a="${b%/*}"

      while [ "x${a}" != "x${b}" ]; do
         i=$(( ${i} + 1 ))
         b="${a}"
         a="${b%/*}"
      done

      v0="${i}"
   fi

   [ -n "${v0}" ]
}

# @function_alias get_fs_level() renames get_fslevel()
#
get_fs_level() { get_fslevel "$@"; }

# int get_fslevel_diff ( fspath1, fspath2 )
#
#  Compares the level of two filesystem paths and returns the difference
#  level(fspath1) - level(fspath2) via %v0.
#
get_fslevel_diff() {
   if get_fslevel "${1?}"; then
      local x="${v0?}"
      if get_fslevel "${2?}"; then
         v0=$(( ${x} - ${v0} ))
         return 0
      else
         v0=
         return 3
      fi
   else
      v0=
      return 2
   fi
}

# @function_alias get_fs_level_diff() renames get_fslevel_diff()
#
get_fs_level_diff() { get_fslevel_diff "$@"; }
