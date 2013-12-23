#@section functions

# void fspath_remove_trailing_slashes ( fspath, **v0! )
#
fspath_remove_trailing_slashes() {
   v0=
   case "${1?}" in
      /)
         v0="${1}"
      ;;
      /*)
         str_remove_trailing_chars "${1}" "/"
         v0="/${v0#/}"
      ;;
      */)
         str_remove_trailing_chars "${1}" "/"
      ;;
      *)
         v0="${1}"
      ;;
   esac
}

# void fspath_remove_leading_slashes ( fspath, **v0! )
#
fspath_remove_leading_slashes() {
   v0=
   case "${1?}" in
      /)
         v0="${1}"
      ;;
      /*)
         str_remove_leading_chars "${1}" "/"
         v0="/${v0}"
      ;;
      */)
         str_remove_leading_chars "${1}" "/"
      ;;
      *)
         v0="${1}"
      ;;
   esac
}

# void fspath_strip ( fspath, **v0! )
#
#  fspath_remove_leading_slashes() and fspath_remove_trailing_slashes()
#  in one function call.
#
fspath_strip() {
   v0=
   case "${1?}" in
      /)
         v0="${1}"
      ;;
      /*)
         str_remove_leading_chars "${1}" "/"
         str_remove_trailing_chars "${v0}" "/"
         v0="/${v0}"
      ;;
      */)
         str_remove_leading_chars "${1}" "/"
         str_remove_trailing_chars "${v0}" "/"
      ;;
      *)
         v0="${1}"
      ;;
   esac
}

# void fspath_trim ( fspath, **v0! )
#
#  Identical to fspath_strip(), but uses sed instead of builtin code.
#
fspath_trim() {
   : ${1?}
   v0="$( echo "${1}" | sed -r -e 's,[/]+,/,g' -e 's,[/]$,,' )"
}


#@section functions

# @private @stdout ~int readlink__abspath ( fspath )
#
#  abspath() function using readlink.
#  No path components need to exist.
#
#  Note that this resolves symlinks. Use realpath__abspath() if possible.
#
#  Linux with GNU coreutils only!
#
readlink__abspath() {
   readlink -m -- "${1?}"
}

# @private @stdout readlink__realpath ( fspath )
#
#  realpath() function using readlink.
#  All path components except the last one must exist.
#
#  Linux with GNU coreutils or busybox only!
#
readlink__realpath() {
   readlink -f -- "${1?}"
}

# @private @stdout ~int readlink__realpath_safe ( fspath )
#
#  realpath_safe() function using readlink.
#  All path components must exist.
#
#  Linux with GNU coreutils only!
#
readlink__realpath_safe() {
   readlink -e -- "${1?}"
}


# @private @stdout ~int realpath__abspath ( fspath )
#
#  abspath() function using realpath.
#
#  Linux with GNU coreutils only!
#
realpath__abspath() {
   realpath -Lsmq -- "${1?}"
}

# @private @stdout ~int realpath__realpath ( fspath )
#
#  realpath() using realpath.
#  All path components except the last one must exist.
#
#  Linux with GNU coreutils only!
#
realpath__realpath() {
   realpath -Lq -- "${1?}"
}

# @private @stdout ~int realpath__realpath_safe ( fspath )
#
#  realpath_safe() function using realpath.
#  All path components must exist.
#
#  Linux with GNU coreutils only!
#
realpath__realpath_safe() {
   realpath -Leq -- "${1?}"
}


#@section functions

# void fspath_bind_implementation (
#    impl, **HAVE_FSPATH_FUNCTIONS!
# ), raises function_die()
#
#  Binds the print_abspath, print_realpath, print_realpath_safe,
#  get_abspath, get_realpath and get_realpath_safe functions according
#  to the given implementation.
#
#  Available implementations:
#  * realpath
#  * readlink
#
fspath_bind_implementation() {
   HAVE_FSPATH_FUNCTIONS=n
   unset -f print_abspath print_realpath print_realpath_safe
   unset -f get_abspath get_realpath get_realpath_safe

   case "${1:?}" in
      realpath)
         print_abspath()       { realpath__abspath "$@"; }
         print_realpath()      { realpath__realpath "$@"; }
         print_realpath_safe() { realpath__realpath_safe "$@"; }

         get_abspath()         { v0="$(realpath__abspath "$@")"; }
         get_realpath()        { v0="$(realpath__realpath "$@")"; }
         get_realpath_safe()   { v0="$(realpath__realpath_safe "$@")"; }
      ;;
      readlink)
         print_abspath()       { readlink__abspath "$@"; }
         print_realpath()      { readlink__realpath "$@"; }
         print_realpath_safe() { readlink__realpath_safe "$@"; }

         get_abspath()         { v0="$(readlink__abspath "$@")"; }
         get_realpath()        { v0="$(readlink__realpath "$@")"; }
         get_realpath_safe()   { v0="$(readlink__realpath_safe "$@")"; }
      ;;
      *)
         function_die "unknown fspath implementation '${1}'" \
            fspath_bind_implementation
      ;;
   esac
   HAVE_FSPATH_FUNCTIONS=y
}

# int get_fspath ( fspath, **v0! )
#
#  Stores the realpath of %fspath in %v0 if it is non-empty,
#  and the abspath otherwise.
#
#  Returns 0 if the resulting path is not empty, else 1.
#
get_fspath() {
   v0=
   get_realpath "${1?}"
   if [ -n "${v0}" ]; then
      return 0
   else
      get_abspath "${1?}"
      [ -n "${v0}" ] || return 1
      return 0
   fi
}

# int get_relpath ( parent_path, path, **v0! )
#
#  Accepts two normalized filesystem paths %parent_path, %path and stores
#  the path of %path relative to %parent_path in %v0 IFF %path is a subpath.
#  Stores the empty str otherwise (%path == %parent_path is a subpath, too).
#
#  Returns 2 if %path == %parent_path, 1 if no relpath set
#  and 0 if successful.
#
get_relpath() {
   v0="${2#${1}}"
   v0="${v0#/}"

   if [ "${v0}" = "${2}" ]; then
      v0=
      return 1
   elif [ -z "${v0}" ]; then
      v0="."
      return 2
   else
      v0="./${v0#/}"
      return 0
   fi
}

# void fspath_bind_functions ( **HAVE_FSPATH_FUNCTIONS! )
#
#  Binds the print_abspath, print_realpath, print_realpath_safe,
#  get_abspath, get_realpath and get_realpath_safe functions according
#  to what's available. realpath is preferred.
#
#  Note that it is *not* checked whether the functions can actually be used
#  (i.e. running a Linux-based system with GNU coreutils etc.).
#  You may want to run fspath_bind_implementation(<name>) to choose a
#  specific implementation.
#
fspath_bind_functions() {
   if qwhich realpath; then
      fspath_bind_implementation realpath
   else
      fspath_bind_implementation readlink
   fi
}

# void fspath_bind_functions_if_required ( **HAVE_FSPATH_FUNCTIONS! )
#
fspath_bind_functions_if_required() {
   [ "${HAVE_FSPATH_FUNCTIONS:-n}" = "y" ] || fspath_bind_functions
}


#@section module_init
if [ $$ -ne 1 ] && [ "${FSPATH_BIND_FUNCTIONS:-y}" = "y" ]; then
   fspath_bind_functions
fi
