# void fs_doprefix ( fspath=, prefix=**FS_PREFIX=, *sub_prefix )
#
#  Applies a prefix to a filesystem path and stores the result in %v0.
#
fs_doprefix() {
   v0=""
   local fspath="${1-}" prefix="${2-${FS_PREFIX-}}" fspath_next

   if [ -n "${3-}" ]; then
      shift 2
      while [ $# -gt 0 ]; do
         fs_doprefix "${1}" "${prefix}"
         prefix="${v0}"
         shift
      done
      #v0=""
   fi

   fspath="${fspath#${prefix%/}}"
   fspath="${prefix%/}/${fspath#/}"

   fspath_next="${fspath%/}"
   while [ "x${fspath}" != "x${fspath_next}" ]; do
      # do 2 removals per iteration
      fspath="${fspath_next%/}"
      fspath_next="${fspath%/}"
   done
   [ -n "${fspath}" ] || fspath="${prefix%/}/"

   v0="${fspath}"
}

# void fs_doprefix_echo ( fspath=, prefix=**FS_PREFIX=, *sub_prefix )
#
#  Like fs_doprefix(), but writes the result to stdout instead of storing
#  it in %v0.
#
fs_doprefix_echo() {
   local v0
   fs_doprefix "$@"
   echo "${v0}"
}

# @undef fs_doprefix_call ( prefix, funcname, file, ... )
#
#  Applies prefix to file and calls funcname ( <prefixed file>, ... )
#  afterwards.
#
fs_doprefix_call() {
   local p="${1-}" func="${2:?}" v0="${3:?}"
   shift 3 && \
   fs_doprefix "${v0}" "${p}" && \
   ${func} "${v0}" "$@"
}
